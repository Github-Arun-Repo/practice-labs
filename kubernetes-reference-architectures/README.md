# Kubernetes Reference Architectures

Kubernetes documentation is everywhere. This section isn't an introduction — it's for engineers who already work with Kubernetes and want production-grade reference implementations for specific operational problems.

Each pattern includes a README explaining the design reasoning and trade-offs, plus a hands-on runbook with failure tests.

---

## Pattern Catalog

| Pattern | Why It Was Created | What It Teaches | Links |
|---|---|---|---|
| **Pattern 1: Shared Cluster Multi-Tenancy** | Multiple teams sharing one cluster without isolation cause resource exhaustion, cross-team security gaps, and operational chaos | Namespace boundaries, ResourceQuotas, LimitRanges, RBAC, NetworkPolicy, and Secrets — all enforced and verified with failure tests | [README](./multi-cluster-strategy/README.md) · [Runbook](./multi-cluster-strategy/multi-cluster-runbook.md) |
| **Pattern 2: Autoscaling (HPA and VPA)** | Static resource allocation either over-provisions (wasted cost) or under-provisions (failures at peak) — neither is acceptable in production | HPA scales replicas based on CPU demand; VPA right-sizes each pod's resource allocation; this pattern runs both and shows where they conflict | [README](./autoscaling-reference-patterns/README.md) · [Runbook](./autoscaling-reference-patterns/autoscaling-runbook.md) |
| **Pattern 3: Zero-Downtime Deployment Strategies** | Every team eventually ships a bad release — the question is how quickly you can recover, and whether your users noticed | Rolling Update, Blue/Green, and Canary deployments with failure scenarios, PodDisruptionBudgets, and rollback validation | [README](./zero-downtime-deployment-strategies/README.md) · [Runbook](./zero-downtime-deployment-strategies/zero-downtime-runbook.md) |
| **Pattern 4: Pod Health Probes** | Startup, liveness, and readiness probes look identical in YAML but trigger completely different outcomes — using the wrong one causes restart storms, apps that never start, or pods stuck out of service | All three probes demonstrated with correct use, anti-patterns, and a side-by-side comparison showing why liveness vs. readiness is the most consequential choice you make in a pod spec | [README](./pod-health-probes/README.md) · [Runbook](./pod-health-probes/probes-runbook.md) |

---

## Prerequisites

→ [Installation and prerequisites](./installation-kubernetes-prerequisites.md)

---

## Navigation

| Section | Link |
|---|---|
| Pattern 1: Shared Cluster Multi-Tenancy | [README](./multi-cluster-strategy/README.md) · [Runbook](./multi-cluster-strategy/multi-cluster-runbook.md) |
| Pattern 2: Autoscaling (HPA + VPA) | [README](./autoscaling-reference-patterns/README.md) · [Runbook](./autoscaling-reference-patterns/autoscaling-runbook.md) |
| Pattern 3: Zero-Downtime Deployments | [README](./zero-downtime-deployment-strategies/README.md) · [Runbook](./zero-downtime-deployment-strategies/zero-downtime-runbook.md) |
| Pattern 4: Pod Health Probes | [README](./pod-health-probes/README.md) · [Runbook](./pod-health-probes/probes-runbook.md) |
| HPA deep dive | [HPA README](./autoscaling-reference-patterns/hpa/README.md) |
| VPA deep dive | [VPA README](./autoscaling-reference-patterns/vpa/README.md) |
| VPA Installation | [installation-vpa.md](./autoscaling-reference-patterns/vpa/installation-vpa.md) |
| Prerequisites | [installation-kubernetes-prerequisites.md](./installation-kubernetes-prerequisites.md) |
| Main repository | [README](../README.md) |
