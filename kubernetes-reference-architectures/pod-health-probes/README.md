# Pod Health Probes

Three probes — startup, liveness, readiness — that look almost identical in YAML syntax but serve completely different purposes and trigger completely different outcomes when they fail. Mixing them up is one of the most common sources of production incidents on Kubernetes.

This pattern works through all three, covers the correct use of each, and demonstrates the anti-patterns explicitly so you know what the wrong configuration looks like in practice.

---

## Quick Start — Choose Your Path

**I want the full timed runbook:**
→ [Run the probes runbook](./probes-runbook.md)

**I want to understand startup probes:**
→ [Startup Probe](#startup-probe)

**I want to understand liveness probes:**
→ [Liveness Probe](#liveness-probe)

**I want to understand readiness probes:**
→ [Readiness Probe](#readiness-probe)

**I want to see what failure looks like for each:**
→ [Anti-Patterns and Failure Scenarios](#anti-patterns-and-failure-scenarios)

**I want all three together on one deployment:**
→ [Combined — All Three Probes](#combined--all-three-probes)

---

## Why This Pattern Exists

The same YAML block — `livenessProbe`, `readinessProbe`, `startupProbe` — looks similar enough that engineers often pick one, configure it, and move on without understanding what they've actually wired up.

The classic mistake: using a liveness probe to check whether a database is reachable. It seems reasonable. If the DB is down, the app can't work — so restart it, right?

What actually happens:
1. Database goes down
2. Liveness probe on every pod fails
3. All pods restart simultaneously
4. Every pod reconnects to the database at the same moment — thundering herd
5. Database recovers but is overwhelmed by reconnection storm
6. Liveness keeps failing, pods keep restarting
7. Your application is now unreachable because of a probe, not because of the database

The correct response when an external dependency goes down: readiness probe fails, pods are removed from Service endpoints (no new traffic), existing connections complete, pods wait for the dependency to recover, re-join service when it does. No restarts. No dropped requests.

This pattern makes that distinction concrete with runnable demos.

---

## The Three Probes

| | Startup | Liveness | Readiness |
|---|---|---|---|
| **Runs when** | Once at startup, until first success | Continuously after startup succeeds | Continuously after startup succeeds |
| **Failure action** | Restart container | Restart container | Remove from Service endpoints — no restart |
| **Success action** | Enables liveness and readiness | No action | Adds to Service endpoints |
| **What it answers** | Has the app finished starting? | Is the app process alive and functional? | Is the app ready to accept traffic right now? |
| **Check external deps?** | No | No | Conditionally — see readiness section |
| **Runs more than once?** | No — stops after first success | Yes — forever | Yes — forever |

---

## Startup Probe

A startup probe protects slow-starting containers. While it runs, liveness and readiness probes are fully disabled. Once it passes, it stops permanently — it's a one-time gate.

**The problem it solves:**
JVM applications, Spring Boot services, anything that runs migrations at startup, or services that need to warm up a cache before serving — all of these can take 30-60 seconds or more to be ready. Without a startup probe, the liveness probe fires during that window and kills the container before it ever finishes starting. The pod enters a restart loop and never serves traffic.

**How the timing works:**
```text
failureThreshold × periodSeconds = maximum startup window

failureThreshold: 12, periodSeconds: 5 → 60-second startup window
```

**What you observe without it:**
```text
NAME                          READY   STATUS             RESTARTS
slow-app-no-startup-probe     0/1     Running            3   ← climbing
slow-app-with-startup-probe   0/1     Running            0   ← waiting patiently
slow-app-with-startup-probe   1/1     Running            0   ← succeeded at ~45s
```

**When to use startup probe:**
- Any container that takes more than `initialDelaySeconds` to be ready
- JVM applications (typically 20-60s)
- Services that run DB migrations at boot
- Containers loading large datasets into memory before serving

**When NOT to use startup probe:**
- Fast-starting containers (Go services, nginx, lightweight APIs) — adds unnecessary delay to first readiness check

---

## Liveness Probe

A liveness probe answers: is this process still alive and functional? Failure triggers a container restart — same outcome as the process crashing.

**The right use case:**
The container is running (OS process is alive, port is open), but the application has entered a broken state it cannot recover from on its own. Examples: deadlock, infinite loop, stuck goroutine, memory state corruption. A restart clears the broken state and the app comes back clean.

**The key constraint:**
Liveness should only check things the container itself can fix by restarting. If the check fails due to something external — database is down, upstream API is slow — the restart makes things worse, not better.

```text
Liveness probe failure:
  Process alive → probe fails → container restart → process alive again
  
  This is useful when:  app is stuck, deadlocked, or in unrecoverable internal state
  This is harmful when: app is fine but an external dependency is unavailable
```

**When to use liveness probe:**
- Detect process deadlocks that a restart would clear
- Detect an application that stops responding to HTTP but doesn't crash
- Long-running services where OOM or state corruption can cause silent failure

**When NOT to use liveness probe:**
- Checking database connectivity (use readiness instead)
- Checking downstream service availability (use readiness instead)
- Anything that isn't directly fixable by restarting the container

---

## Readiness Probe

A readiness probe answers: is this container ready to receive traffic right now? Failure removes the pod from Service endpoints. The container is NOT restarted. The process keeps running.

This distinction is the most important thing to understand about probes. Readiness failure is reversible — the pod can go in and out of the endpoint list any number of times without impacting process state or dropping existing connections.

**What it enables:**
- **Startup warmup**: pod is alive but still loading caches or warming connections — traffic waits
- **Temporary overload**: pod is running but at capacity — traffic routes to other pods, pod catches up
- **External dependency down**: DB is unreachable — pod signals unready, no new queries come in, pod retries when DB recovers and re-joins service automatically
- **Graceful drain**: before taking a pod out for maintenance, signal unready, wait for inflight requests to drain

**What happens to in-flight requests during unreadiness:**
The pod is removed from the load balancer endpoint list. No new requests are routed to it. But the container process is still running — any connections already established continue until they complete normally. Nothing is dropped.

**Should readiness check external dependencies?**
Conditional. Checking a primary database connection is reasonable — if the app cannot serve useful traffic without the DB, readiness accurately reflects that. Checking every downstream dependency can make the pod unstable (a single flapping sidecar takes the whole pod out). Be selective.

---

## Anti-Patterns and Failure Scenarios

**Anti-pattern 1: Liveness probe checking external dependencies**

```yaml
# WRONG: this will cause restart storms when the database goes down
livenessProbe:
  exec:
    command: ["sh", "-c", "pg_isready -h my-database || exit 1"]
```

When the database goes down: all pods fail liveness simultaneously → all restart → reconnection storm → database overwhelmed → liveness keeps failing → app never recovers.

The demo in the runbook shows this with a file-based version of the same problem: delete `/tmp/healthy` (simulating a dependency going down) → pod restarts. Then do the same operation on the readiness version → pod gracefully exits service, no restart.

**Anti-pattern 2: No startup probe on a slow-starting app**

Covered in the startup probe section. The restart loop means the app never starts. This is a common surprise for teams migrating Java or .NET services to Kubernetes from VMs, where the equivalent of a startup probe was always implicit in the process supervisor.

**Anti-pattern 3: Startup probe with a very short window**

```yaml
startupProbe:
  failureThreshold: 3
  periodSeconds: 5
  # Total window: 15 seconds — too short for a Java app
```

The startup probe fails before the app is ready. Container restarts. Same restart loop as having no startup probe, just slower. Match `failureThreshold × periodSeconds` to your application's observed startup time plus headroom.

**Anti-pattern 4: Too aggressive liveness probe on a healthy app**

```yaml
livenessProbe:
  httpGet:
    path: /heavy-query
  periodSeconds: 5
  failureThreshold: 1
  # One slow response = immediate restart
```

If the health endpoint does any real work (DB query, external call), a slow response under load causes a restart. The restart happens under load, drops connections, and the load redistributes to other pods — which may also be under load and slow. Cascading restart storm. Keep liveness checks lightweight and idempotent.

---

## Demo Application

All scenarios use `nginx:1.24-alpine` (for startup, readiness, combined, and the liveness anti-pattern demo) and `registry.k8s.io/liveness` (for the liveness correct-use demo).

`registry.k8s.io/liveness` is the official Kubernetes probe example container. It returns HTTP 200 on `/healthz` for the first 10 seconds, then returns HTTP 500 permanently — simulating a deadlock. The liveness probe detects this and restarts the container. The cycle repeats.

For readiness and the liveness anti-pattern, a postStart lifecycle hook creates `/tmp/ready` (or `/tmp/healthy`) at container start. The probes check for this file. The runbook walks through manually toggling the file via `kubectl exec` to trigger the probe states.

No Docker builds required. No custom images.

---

## Decision Framework

| Situation | Use this probe |
|---|---|
| App takes >20 seconds to start (JVM, .NET, migration runners) | Startup probe — give it a generous window |
| App process can deadlock or get stuck without crashing | Liveness probe |
| App needs time to warm up before serving traffic | Readiness probe (don't use liveness) |
| External dependency (DB, API) is temporarily unavailable | Readiness probe (never liveness) |
| App is temporarily overloaded and can't take new requests | Readiness probe |
| Pre-maintenance graceful drain | Readiness probe — signal unready, let inflight drain |
| App crashes on its own | Neither needed — Kubernetes restarts crashed containers by default |

---

## Folder Layout

```text
pod-health-probes/
├── README.md                              ← this file
├── probes-runbook.md                      ← timed runbook, directly executable
├── startup-probe/
│   └── k8s/
│       ├── namespace.yaml                 ← startup-demo namespace
│       ├── deployment-without-startup.yaml ← the PROBLEM: restart loop
│       └── deployment-with-startup.yaml   ← the SOLUTION: 60-second window
├── liveness-probe/
│   └── k8s/
│       ├── namespace.yaml                 ← liveness-demo namespace
│       ├── deployment.yaml                ← registry.k8s.io/liveness: correct use
│       └── deployment-anti-pattern.yaml   ← file-based liveness: shows wrong use
├── readiness-probe/
│   └── k8s/
│       ├── namespace.yaml                 ← readiness-demo namespace
│       ├── deployment.yaml                ← 3 replicas, /tmp/ready file-based probe
│       └── service.yaml                   ← ClusterIP — shows endpoint changes
├── combined/
│   └── k8s/
│       ├── namespace.yaml                 ← combined-demo namespace
│       ├── deployment.yaml                ← all three probes, production-configured
│       └── service.yaml
└── scripts/
    ├── 00-cleanup.sh                      ← removes all four demo namespaces
    ├── 01-startup-problem.sh              ← deploy slow app without startup probe
    ├── 02-startup-solution.sh             ← deploy same app with startup probe
    ├── 03-watch-startup.sh                ← watch loop: compare RESTARTS side by side
    ├── 04-liveness-demo.sh                ← deploy liveness-demo + anti-pattern
    ├── 05-watch-liveness.sh               ← watch loop: observe restart counter
    ├── 06-readiness-demo.sh               ← deploy 3-replica readiness demo
    ├── 07-toggle-unready.sh               ← remove /tmp/ready from one pod
    ├── 08-toggle-ready.sh                 ← create /tmp/ready on that pod
    └── 09-combined-demo.sh                ← deploy all-three-probes deployment
```

---

## Learning Path

1. Read this README to understand what each probe does and why the distinctions matter.
2. Execute [probes-runbook.md](./probes-runbook.md) from top to bottom.
3. Pay close attention to Part 3: compare the liveness anti-pattern with the readiness correct-use — the same file deletion produces completely different outcomes.
4. Run the combined demo and inspect the probe configuration on a live pod.
5. Run cleanup and verify the cluster is clean.

---

## Navigation

- [Back to Kubernetes Reference Architectures](../README.md)
- [Pattern 1: Shared Cluster Multi-Tenancy](../multi-cluster-strategy/README.md)
- [Pattern 2: Autoscaling (HPA and VPA)](../autoscaling-reference-patterns/README.md)
- [Pattern 3: Zero-Downtime Deployment Strategies](../zero-downtime-deployment-strategies/README.md)
