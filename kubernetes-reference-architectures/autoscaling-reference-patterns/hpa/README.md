# Horizontal Pod Autoscaler (HPA)

## What Is HPA?

HPA is a Kubernetes controller that automatically adjusts the number of pod replicas in a Deployment based on observed resource metrics. It is built into Kubernetes and requires no additional installation beyond the metrics-server.

The HPA controller runs in the control plane and operates on a reconciliation loop — typically every 15 seconds. Each loop it reads current metrics, applies the scaling algorithm, and updates the Deployment replica count.

---

## How the Scaling Algorithm Works

```
desiredReplicas = ceil [ currentReplicas × ( currentMetricValue ÷ desiredMetricValue ) ]
```

Concrete example at runtime:
- currentReplicas: 2
- currentMetricValue: 80% CPU (average across pods)
- desiredMetricValue: 50% CPU target
- desiredReplicas = ceil [ 2 × (80 ÷ 50) ] = ceil [3.2] = 4

HPA adds 2 replicas to bring average CPU down toward 50%.

---

## Metrics Types

| Type | Description | Example |
|---|---|---|
| Resource | CPU or memory as % of requests | `cpu: 50%` |
| External | Metrics from outside the cluster | queue depth, request rate |
| Custom | App-generated metrics via Custom Metrics API | active connections, latency |

**Start with CPU-based HPA.** It is the most straightforward, directly observable, and supported out of the box without additional instrumentation.

---

## Scale-Up vs Scale-Down Behavior

**Scale-up** is intentionally fast — when load increases, you want new pods immediately.
**Scale-down** is intentionally slow — a momentary dip in load should not remove pods that are still needed.

Default behavior (Kubernetes 1.18+):
- Scale-up: immediate once metric threshold is crossed
- Scale-down: only after the stabilization window (default 300 seconds) of sustained low load

The `hpa-cpu.yaml` in this pattern uses a 60-second scale-down stabilization window to make scale-down observable during a live walkthrough. In production, use 300 seconds or higher.

---

## What Happens at Min and Max Replicas

- **minReplicas**: HPA will never scale below this value. Even with zero traffic, the Deployment keeps this many replicas running. Set to 1 to preserve availability.
- **maxReplicas**: HPA will never scale above this value. Protects against runaway scaling due to a spike or metric anomaly. Always set a sensible ceiling.

---

## When To Use HPA

| Scenario | HPA is appropriate |
|---|---|
| Stateless HTTP/API services | Yes |
| Workloads with bursty CPU demand | Yes |
| Queue consumers that need more workers under load | Yes (with custom metrics) |
| Stateful sets where scaling is complex | With caution |
| Batch jobs | No — use Job parallelism instead |

---

## When NOT To Use HPA

- **No resource requests defined**: HPA cannot calculate utilization without requests. Always set resource requests on your containers.
- **metrics-server not installed**: HPA falls back to Unknown metrics and cannot act.
- **Very short-lived spikes**: Pod startup time may exceed the spike duration. Consider pre-scaling or keeping higher minReplicas.

---

## HPA and VPA Together

HPA and VPA can coexist on the same Deployment but with one rule: **they must not both control the same resource dimension**.

Safe combination:
- HPA on CPU + VPA on memory only (`controlledResources: ["memory"]`)

Unsafe combination:
- HPA on CPU + VPA Auto on CPU → they fight: VPA restarts pods while HPA is scaling up

---

## Files in This Pattern

| File | Purpose |
|---|---|
| `k8s/hpa-cpu.yaml` | CPU-based HPA, 50% target, min 1 max 10, demo-tuned cooldown |
| `k8s/hpa-memory.yaml` | Memory-based HPA reference (70% target) |

---

## Runbook

→ [autoscaling-runbook.md](../autoscaling-runbook.md) — Part 1 covers HPA end to end
