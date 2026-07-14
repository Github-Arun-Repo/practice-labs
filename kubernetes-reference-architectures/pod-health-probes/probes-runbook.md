# Pod Health Probes — Runbook

**Repo:** `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
**Base folder:** `kubernetes-reference-architectures/pod-health-probes/` (all commands run from here)
**Cluster:** Standalone Kubernetes on EC2
**Presenter:** Arunasalam Govindasamy

---

## Repo Layout

```text
pod-health-probes/
├── probes-runbook.md                ← this file
├── startup-probe/k8s/
│   ├── namespace.yaml               # startup-demo namespace
│   ├── deployment-without-startup.yaml   # the problem: restart loop
│   └── deployment-with-startup.yaml      # the solution: startup window
├── liveness-probe/k8s/
│   ├── namespace.yaml               # liveness-demo namespace
│   ├── deployment.yaml              # correct use: registry.k8s.io/liveness
│   └── deployment-anti-pattern.yaml # wrong use: external dep checked via liveness
├── readiness-probe/k8s/
│   ├── namespace.yaml               # readiness-demo namespace
│   ├── deployment.yaml              # correct use: file-based readiness, 3 replicas
│   └── service.yaml
├── combined/k8s/
│   ├── namespace.yaml               # combined-demo namespace
│   ├── deployment.yaml              # all three probes, production-configured
│   └── service.yaml
└── scripts/
    ├── 00-cleanup.sh
    ├── 01-startup-problem.sh
    ├── 02-startup-solution.sh
    ├── 03-watch-startup.sh          # run in a second terminal
    ├── 04-liveness-demo.sh
    ├── 05-watch-liveness.sh         # run in a second terminal
    ├── 06-readiness-demo.sh
    ├── 07-toggle-unready.sh
    ├── 08-toggle-ready.sh
    └── 09-combined-demo.sh
```

---

## Timing Plan

- Pre-flight: ≈ 5 min
- Part 1 — Startup Probe: ≈ 15 min
- Part 2 — Liveness Probe: ≈ 15 min
- Part 3 — Readiness Probe + Anti-Pattern Comparison: ≈ 20 min
- Part 4 — Combined Probes: ≈ 10 min
- Part 5 — Failure Scenarios: ≈ 10 min
- Cleanup: ≈ 5 min
- **Total: ≈ 80 min**

---

## 0. Pre-Flight

```bash
# Pull latest
cd ~/projects/platform-engineering-reference-architectures && git pull

# Move into working directory — all commands run from here
cd kubernetes-reference-architectures/pod-health-probes

# Make scripts executable
chmod +x scripts/*.sh

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Clean slate
./scripts/00-cleanup.sh

echo "Ready."
```

---
---

# PART 1 — Startup Probe (≈15 min)

> **Goal:** Show what happens to a slow-starting app without a startup probe (restart loop), then fix it by adding a startup probe and watch the pod start successfully.

---

## 1.1 — Deploy the Problem: Slow App Without Startup Probe

```bash
./scripts/01-startup-problem.sh
```

Open a **second terminal** and start the watcher:

```bash
# Second terminal:
./scripts/03-watch-startup.sh
```

👉 The container sleeps 45 seconds before nginx starts. The liveness probe fires at t=5s, allows 3 failures, kills the pod at ~t=15s. The pod restarts and immediately tries again — hitting the same wall.

Watch for:
```text
NAME                           READY   STATUS    RESTARTS   AGE
slow-app-no-startup-probe      0/1     Running   1          20s
slow-app-no-startup-probe      0/1     Running   2          40s
slow-app-no-startup-probe      0/1     Running   3          60s
```

👉 RESTARTS climbs every ~20 seconds. The app never serves traffic.

Check the kill reason in events:
```bash
kubectl describe pod -n startup-demo -l scenario=problem | grep -A 5 "Liveness"
```

Expected: `Liveness probe failed: Get "http://...:80/": dial tcp ... connection refused`

---

## 1.2 — Deploy the Solution: Same App With Startup Probe

```bash
./scripts/02-startup-solution.sh
```

👉 Now watch both pods side by side in the watcher terminal.

```text
NAME                            READY   STATUS    RESTARTS   AGE
slow-app-no-startup-probe       0/1     Running   4          80s    ← still climbing
slow-app-with-startup-probe     0/1     Running   0          15s    ← waiting patiently
...
slow-app-with-startup-probe     1/1     Running   0          50s    ← succeeded at ~45s
```

👉 `RESTARTS` stays at 0. The startup probe absorbs all the failed checks during the 45-second sleep. The moment nginx starts responding, the startup probe passes, and both the liveness and readiness probes activate.

Inspect the probe sequence on the working pod:
```bash
POD=$(kubectl get pods -n startup-demo -l scenario=solution -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD -n startup-demo | grep -A 8 "Probe:"
```

👉 Three probe sections: `Startup`, `Liveness`, `Readiness` — all configured.

---

## 1.3 — What the Startup Probe Actually Does

```bash
# Show the startup probe window calculation
kubectl get deployment slow-app-with-startup-probe -n startup-demo \
  -o jsonpath='{.spec.template.spec.containers[0].startupProbe}'
```

Expected:
```json
{"failureThreshold":12,"httpGet":{"path":"/","port":80},"periodSeconds":5}
```

👉 `12 × 5 = 60 seconds`. The startup probe allows 60 seconds for the app to start. If it doesn't start in time: the pod is killed (same outcome as a liveness failure). If it passes: liveness and readiness take over.

---
---

# PART 2 — Liveness Probe (≈15 min)

> **Goal:** Demonstrate a correct use of liveness (auto-restart a stuck app), then demonstrate the anti-pattern (liveness checking an external dependency) and observe the restart behavior.

---

## 2.1 — Deploy and Watch Liveness Demo

```bash
./scripts/04-liveness-demo.sh
```

Open a **second terminal** and watch:

```bash
./scripts/05-watch-liveness.sh
```

`liveness-demo` uses `registry.k8s.io/liveness`, which returns HTTP 200 for 10 seconds, then HTTP 500 forever. This simulates an application that gets into a broken state without crashing.

Watch the restart cycle:
```text
NAME               READY   STATUS    RESTARTS   AGE
liveness-demo      1/1     Running   0          8s
liveness-demo      1/1     Running   1          35s   ← first restart
liveness-demo      1/1     Running   2          70s   ← second restart
```

👉 RESTARTS keeps incrementing. The container process never crashes — the liveness probe detects the broken state and forces the restart. This is the correct use: Kubernetes is acting as the supervisor for a broken-but-running app.

---

## 2.2 — Understand Why This is the Right Use

```bash
kubectl describe pod -n liveness-demo -l app=liveness-demo | grep -A 10 "Events:"
```

Expected events:
```
Liveness probe failed: HTTP probe failed with statuscode: 500
Killing container with id ...: liveness probe failed
```

👉 The probe detected the 500 response. The container was restarted. This is intentional behavior — the app needed a restart to clear its broken state.

The key: **the restart actually fixes the problem** (the container comes back clean and serves 200 for 10 more seconds). That's what separates a good liveness probe use case from a bad one.

---

## 2.3 — Demonstrate the Anti-Pattern

The `liveness-anti-pattern` pod uses a liveness probe that checks for `/tmp/healthy` — representing an external dependency.

```bash
APOD=$(kubectl get pods -n liveness-demo -l app=liveness-anti-pattern \
  -o jsonpath='{.items[0].metadata.name}')

# Confirm it's healthy
kubectl exec $APOD -n liveness-demo -- ls /tmp/healthy
kubectl get pods -n liveness-demo -l app=liveness-anti-pattern
```

👉 Pod is 1/1 Ready. RESTARTS is 0.

Now simulate the "external dependency going down":
```bash
kubectl exec $APOD -n liveness-demo -- rm -f /tmp/healthy
```

Watch:
```bash
kubectl get pods -n liveness-demo -w
```

👉 Within ~10 seconds: pod restarts. RESTARTS goes to 1.

But the postStart hook creates `/tmp/healthy` again at restart — so after the restart, the probe passes again. If this were a real database that was still down, the cycle would repeat: restart, liveness passes briefly, then fails again as the DB is still unreachable. Endless restart loop.

```bash
# The restart dropped in-flight requests
kubectl get pods -n liveness-demo -l app=liveness-anti-pattern
# RESTARTS: 1 (and it might climb again if you delete the file again)
```

---
---

# PART 3 — Readiness Probe + Anti-Pattern Comparison (≈20 min)

> **Goal:** Deploy the readiness demo, confirm all 3 pods are in service, remove one pod from service without a restart, add it back, then compare directly with the liveness anti-pattern from Part 2.

---

## 3.1 — Deploy Readiness Demo

```bash
./scripts/06-readiness-demo.sh
```

```bash
kubectl get pods -n readiness-demo -o wide
kubectl get endpoints readiness-demo -n readiness-demo
```

👉 3 pods running, all 1/1 Ready. All three IPs appear in the Service endpoints.

---

## 3.2 — Remove One Pod From Service (No Restart)

```bash
./scripts/07-toggle-unready.sh
```

This deletes `/tmp/ready` from one pod. The readiness probe fails on the next check (~5s). The pod is removed from Service endpoints.

```bash
kubectl get pods -n readiness-demo -o wide
kubectl get endpoints readiness-demo -n readiness-demo
```

👉 One pod shows `0/1 READY`. That pod's IP is gone from endpoints. **RESTARTS is still 0.**

```bash
# Confirm the pod process is still running
POD=$(kubectl get pods -n readiness-demo -l app=readiness-demo \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n readiness-demo -- nginx -v
```

👉 nginx is still running. The container is alive. The pod is just not receiving new traffic.

---

## 3.3 — Add the Pod Back to Service

```bash
./scripts/08-toggle-ready.sh
```

```bash
kubectl get pods -n readiness-demo -o wide
kubectl get endpoints readiness-demo -n readiness-demo
```

👉 All 3 pods back to 1/1 READY. All three IPs back in endpoints. RESTARTS still 0.

The pod went: in service → out of service → back in service, without ever restarting. Any in-flight requests on that pod completed normally during the unready window.

---

## 3.4 — Side-by-Side Comparison: Liveness vs. Readiness

This is the core of the demo. Same operation (remove a health file), two completely different outcomes.

```bash
# Liveness anti-pattern pod (from Part 2)
APOD=$(kubectl get pods -n liveness-demo -l app=liveness-anti-pattern \
  -o jsonpath='{.items[0].metadata.name}')
echo "Before:"
kubectl get pod $APOD -n liveness-demo --no-headers | awk '{print "  READY: "$2, "RESTARTS: "$4}'

kubectl exec $APOD -n liveness-demo -- rm -f /tmp/healthy
echo "Waiting 15s..."
sleep 15
echo "After (liveness):"
kubectl get pod $APOD -n liveness-demo --no-headers | awk '{print "  READY: "$2, "RESTARTS: "$4}'
```

```bash
# Readiness pod (same operation)
RPOD=$(kubectl get pods -n readiness-demo -l app=readiness-demo \
  -o jsonpath='{.items[0].metadata.name}')
echo "Before:"
kubectl get pod $RPOD -n readiness-demo --no-headers | awk '{print "  READY: "$2, "RESTARTS: "$4}'

kubectl exec $RPOD -n readiness-demo -- rm -f /tmp/ready
echo "Waiting 15s..."
sleep 15
echo "After (readiness):"
kubectl get pod $RPOD -n readiness-demo --no-headers | awk '{print "  READY: "$2, "RESTARTS: "$4}'
```

Expected:
```text
After (liveness):   READY: 1/1  RESTARTS: 2   ← restarted
After (readiness):  READY: 0/1  RESTARTS: 0   ← out of service, alive
```

👉 Same file deletion. Liveness restarts the pod (drops connections, loses state). Readiness gracefully removes the pod from traffic (connections complete, state preserved).

---
---

# PART 4 — Combined Probes (≈10 min)

> **Goal:** Deploy a single production-grade deployment with all three probes and walk through what each one is doing.

---

## 4.1 — Deploy and Inspect

```bash
./scripts/09-combined-demo.sh
```

```bash
kubectl get pods -n combined-demo -o wide
kubectl get endpoints combined-demo -n combined-demo
```

👉 3 pods running, all 1/1 Ready, all in service.

Inspect all three probes on a live pod:
```bash
POD=$(kubectl get pods -n combined-demo -l app=combined-demo \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod $POD -n combined-demo -o json | \
  python3 -c "
import json, sys
c = json.load(sys.stdin)['spec']['containers'][0]
print('startupProbe: ', json.dumps(c.get('startupProbe'), indent=2))
print('livenessProbe:', json.dumps(c.get('livenessProbe'), indent=2))
print('readinessProbe:', json.dumps(c.get('readinessProbe'), indent=2))
"
```

---

## 4.2 — Verify Each Probe Is Active

```bash
# Startup probe already passed (pod is running)
# Liveness probe — check current status
kubectl describe pod $POD -n combined-demo | grep -A 5 "Liveness:"
kubectl describe pod $POD -n combined-demo | grep -A 5 "Readiness:"

# Confirm readiness file exists
kubectl exec $POD -n combined-demo -- ls -la /tmp/ready
```

---

## 4.3 — Test Readiness Toggle on Combined Pod

```bash
# Remove from service
kubectl exec $POD -n combined-demo -- rm -f /tmp/ready
sleep 15
kubectl get pods -n combined-demo -o wide
kubectl get endpoints combined-demo -n combined-demo
```

👉 Target pod shows 0/1 READY. Its IP missing from endpoints. RESTARTS still 0.

```bash
# Add back to service
kubectl exec $POD -n combined-demo -- touch /tmp/ready
sleep 10
kubectl get pods -n combined-demo -o wide
```

👉 Back to 1/1 READY. This is the readiness probe working independently of liveness and startup.

---
---

# PART 5 — Failure Scenarios (≈10 min)

> **Goal:** Verify the startup probe window and observe what happens when a startup probe exceeds its failure threshold.

---

## 5.1 — Exhaust the Startup Probe Window

Deploy a version that takes longer than the startup probe allows:

```bash
# Deploy a container with 90-second startup but only 30-second probe window
kubectl apply -n startup-demo -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: startup-timeout-demo
  namespace: startup-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: startup-timeout-demo
  template:
    metadata:
      labels:
        app: startup-timeout-demo
    spec:
      containers:
        - name: app
          image: nginx:1.24-alpine
          command: ["/bin/sh", "-c"]
          args:
            - |
              echo "Starting... this will take 90 seconds"
              sleep 90
              exec nginx -g 'daemon off;'
          ports:
            - containerPort: 80
          startupProbe:
            httpGet:
              path: /
              port: 80
            failureThreshold: 6
            periodSeconds: 5
            # Window: 6 × 5s = 30 seconds — not enough for a 90-second startup
EOF
```

```bash
kubectl get pods -n startup-demo -l app=startup-timeout-demo -w
```

👉 Expected: after ~30 seconds the pod is killed and restarts. Even startup probes have limits — you must set `failureThreshold × periodSeconds` larger than your app's worst-case startup time, with margin.

Cleanup:
```bash
kubectl delete deployment startup-timeout-demo -n startup-demo --ignore-not-found
```

---

## 5.2 — What Events Show During a Probe Failure

Always check events when a pod behaves unexpectedly:

```bash
kubectl get events -n startup-demo --sort-by='.lastTimestamp' | tail -10
kubectl get events -n liveness-demo --sort-by='.lastTimestamp' | tail -10
kubectl get events -n readiness-demo --sort-by='.lastTimestamp' | tail -10
```

👉 Events surface the probe type, failure reason, and action taken. This is the first place to look when a pod won't start, keeps restarting, or refuses to join service.

---

## Final Cleanup

```bash
./scripts/00-cleanup.sh

kubectl get ns | grep -E 'startup|liveness|readiness|combined'
# Expected: no output
```

---

## Navigation

- [README — Pod Health Probes](./README.md)
- [Back to Kubernetes Reference Architectures](../README.md)
