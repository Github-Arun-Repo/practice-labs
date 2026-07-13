# Vertical Pod Autoscaler (VPA)

## What Is VPA?

VPA automatically adjusts the CPU and memory resource requests of running containers based on observed usage. Where HPA adds more replicas, VPA right-sizes each replica.

VPA is not built into Kubernetes by default. It must be installed separately. See [installation-vpa.md](./installation-vpa.md).

---

## VPA Architecture: Three Components

VPA is made of three controllers:

```
┌────────────────────────────────────────────────────────────────────┐
│                     VPA Architecture                               │
│                                                                    │
│   ┌──────────────┐   Reads metrics     ┌────────────────────────┐  │
│   │  Recommender │──────────────────→  │  metrics-server / API  │  │
│   │              │                     └────────────────────────┘  │
│   │  Produces:   │   Writes recommendations to VPA .status         │
│   │  - lowerBound│────────────────────────────────────────────────┐ │
│   │  - target    │                                                │ │
│   │  - upperBound│                                                │ │
│   └──────────────┘                                                │ │
│                                                                    │ │
│   ┌──────────────┐   Reads VPA .status  ┌─────────────────────┐  │ │
│   │   Updater    │──────────────────→   │  Evicts running pods│  │ │
│   │              │                      │  to apply new values│  │ │
│   └──────────────┘                      └─────────────────────┘  │ │
│                                                                    │ │
│   ┌──────────────────────────┐                                    │ │
│   │  Admission Controller    │  Sets resources on NEW pods         │ │
│   │  (MutatingWebhook)       │  at creation time                  │ │
│   └──────────────────────────┘                                    │ │
└────────────────────────────────────────────────────────────────────┘
```

---

## The Three VPA Modes

| Mode | What It Does | When To Use |
|---|---|---|
| `Off` | Collects data and produces recommendations. Does NOT modify any pods. | Safe start — see what VPA recommends before committing |
| `Initial` | Applies recommendations only when a new pod is created. Running pods are never evicted. | Right-size on restart without disrupting live workloads |
| `Auto` | Evicts running pods and recreates them with updated resource values. | Production right-sizing where restarts are acceptable |

---

## What VPA Recommends: Lower, Target, Upper

For each container, VPA produces three values:

- **lowerBound**: Minimum resources the container is observed to need. Requests below this will likely cause performance issues.
- **target**: The recommended request value — what VPA will apply when it acts.
- **upperBound**: Maximum beyond which additional allocation is unlikely to help. Setting limits here is reasonable.

Read them with:
```bash
kubectl describe vpa <name> -n autoscaling-demo
```

---

## VPA and HPA Compatibility

| Combination | Safe? | Notes |
|---|---|---|
| VPA Off + HPA CPU | Yes | VPA only observes, HPA runs normally |
| VPA Auto + HPA CPU | No | Both control CPU — they conflict |
| VPA Auto (memory only) + HPA CPU | Yes | Each controls a different resource |
| VPA Auto + no HPA | Yes | VPA has full control of resource sizing |

The safe production pattern for using both:
```yaml
# VPA controls memory only
controlledResources: ["memory"]
# HPA controls CPU
metrics: [{resource: {name: cpu}}]
```

---

## Important Operational Notes

- VPA in Auto mode **will restart your pods**. It evicts and recreates them one at a time.
- VPA needs at least a few minutes of data before producing recommendations.
- If your pods have no resource requests, VPA cannot operate.
- VPA should not manage DaemonSets or StatefulSets with persistent storage without careful evaluation.

---

## Files in This Pattern

| File | Purpose |
|---|---|
| `k8s/vpa-recommendation-only.yaml` | VPA in Off mode — safe, no pod restarts, produces recommendations |
| `k8s/vpa-auto.yaml` | VPA in Auto mode — applies recommendations by restarting pods |
| `installation-vpa.md` | Step-by-step VPA installation guide |

---

## Runbook

→ [autoscaling-runbook.md](../autoscaling-runbook.md) — Part 2 covers VPA end to end
