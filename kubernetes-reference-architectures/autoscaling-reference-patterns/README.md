# Autoscaling Reference Patterns

## What Is This?

This pattern demonstrates how Kubernetes automatically adjusts workload capacity in response to real-time demand — either by scaling the number of replicas (HPA) or by right-sizing the resources allocated to each replica (VPA).

Beyond showing the manifests, this documentation explains the architectural reasoning: why autoscaling exists, how each mechanism works, when to use each, and how to observe and validate them under load.

---

## Quick Start — Choose Your Path

**I want to run the autoscaling patterns hands-on now:**
→ [Run the autoscaling runbook](./autoscaling-runbook.md)

**I want to understand HPA in depth:**
→ [HPA — Horizontal Pod Autoscaler](./hpa/README.md)

**I want to understand VPA in depth:**
→ [VPA — Vertical Pod Autoscaler](./vpa/README.md)

**VPA is not installed on my cluster:**
→ [VPA Installation Guide](./vpa/installation-vpa.md)

**I want to verify prerequisites first:**
→ [Prerequisites check](#prerequisites)

---

## Why This Pattern Exists

Static resource allocation fails in two directions:

1. **Under-provisioned**: At peak demand, pods cannot keep up. Latency increases, requests fail, pods crash.
2. **Over-provisioned**: At normal demand, reserved CPU and memory sit idle. Cluster capacity is wasted.

The autoscaling patterns solve both problems:

- **HPA** adds or removes pod replicas dynamically. More demand → more pods. Less demand → fewer pods.
- **VPA** adjusts what each pod is allocated. Under-resourced → recommend more. Over-resourced → recommend less.

---

## Architecture Overview

```text
                    ┌─────────────────────────────────────────────────┐
                    │             Kubernetes Control Plane             │
                    │                                                  │
                    │   ┌──────────────┐    ┌──────────────────────┐  │
                    │   │  HPA Controller│   │  VPA Recommender     │  │
                    │   │  (built-in)   │   │  VPA Updater         │  │
                    │   │               │   │  VPA Admission Ctrl  │  │
                    │   └──────┬───────┘    └──────────┬───────────┘  │
                    │          │                       │               │
                    │          │  reads metrics        │               │
                    │          ▼                       ▼               │
                    │   ┌──────────────────────────────────────────┐  │
                    │   │           metrics-server                  │  │
                    │   └──────────────────────────────────────────┘  │
                    └─────────────────────────────────────────────────┘
                               │                       │
                  Scale replicas                Right-size requests
                               │                       │
                               ▼                       ▼
                    ┌────────────────────────────────────────┐
                    │           Deployment: php-apache        │
                    │   ┌──────┐  ┌──────┐  ┌──────┐        │
                    │   │ Pod  │  │ Pod  │  │ Pod  │        │
                    │   └──────┘  └──────┘  └──────┘        │
                    │        HPA adds/removes pods            │
                    │        VPA adjusts pod resources        │
                    └────────────────────────────────────────┘
```

---

## HPA vs VPA: When To Use Each

| Dimension | HPA | VPA |
|---|---|---|
| What it controls | Number of replicas | Resources per replica (cpu/memory requests) |
| Metric source | CPU%, memory%, custom metrics | Historical resource usage |
| Response to load spike | Add more pods | Restart pod with larger allocation |
| Speed of response | Fast (15-30 seconds) | Slow (minutes, requires pod restart) |
| Best for | Stateless services, APIs, queue consumers | Right-sizing workloads, reducing waste |
| Disruption | None (adds/removes pods) | Pod restarts (in Auto mode) |
| Works without metrics-server | No | No |

---

## The Safe Combination

HPA and VPA can coexist on the same Deployment with one rule: **they must not both control the same resource dimension**.

```text
Recommended combination:

  HPA  ──── controls ────▶  CPU (scale out under load)
  VPA  ──── controls ────▶  Memory only (right-size allocation)
```

Unsafe:
```text
  HPA  ──── controls ────▶  CPU
  VPA  ──── controls ────▶  CPU    ← conflict: VPA evicts what HPA just scaled
```

---

## Prerequisites

Before running the autoscaling runbook:

**1. metrics-server must be installed and working:**
```bash
kubectl top nodes
kubectl top pods -A
```

If `kubectl top` fails, install metrics-server:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

For clusters where kubelet certificates are self-signed (common on EC2):
```bash
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

**2. For VPA sections: VPA must be installed separately:**
→ [VPA Installation Guide](./vpa/installation-vpa.md)

---

## About the Sample Application

The sample application is `registry.k8s.io/hpa-example` — the official Kubernetes HPA test application. It is a PHP/Apache server that computes square roots on every HTTP request, making it CPU-intensive by design.

**Why this app:**
- Produces predictable, measurable CPU load per request
- Used in the official Kubernetes documentation for HPA
- No custom Docker image build required
- Resource requests set at 200m CPU — easily triggered by a busybox load generator

---

## Folder Layout

```text
autoscaling-reference-patterns/
├── README.md                              ← this file
├── autoscaling-runbook.md                 ← timed runbook, directly executable
├── sample-app/
│   └── k8s/
│       ├── namespace.yaml
│       ├── deployment.yaml                ← php-apache, 200m CPU request
│       └── service.yaml
├── hpa/
│   ├── README.md                          ← HPA fundamentals and design guide
│   └── k8s/
│       ├── hpa-cpu.yaml                   ← CPU-based HPA, 50% target
│       └── hpa-memory.yaml                ← Memory-based HPA reference
├── vpa/
│   ├── README.md                          ← VPA fundamentals and design guide
│   ├── installation-vpa.md               ← VPA cluster installation steps
│   └── k8s/
│       ├── vpa-recommendation-only.yaml   ← VPA Off mode, no pod restarts
│       └── vpa-auto.yaml                  ← VPA Auto mode, applies by restart
└── scripts/
    ├── 00-cleanup.sh                      ← full teardown
    ├── 01-deploy-sample-app.sh
    ├── 02-apply-hpa.sh
    ├── 03-generate-load.sh
    ├── 04-watch-hpa.sh
    ├── 05-stop-load.sh
    ├── 06-apply-vpa-recommendation.sh
    └── 07-watch-vpa.sh
```

---

## Learning Path

1. Read this README to understand HPA vs VPA and the combination strategy.
2. Review [HPA README](./hpa/README.md) and [VPA README](./vpa/README.md) for depth.
3. Install prerequisites (metrics-server, VPA).
4. Execute [autoscaling-runbook.md](./autoscaling-runbook.md) from top to bottom.
5. Run failure scenarios in Part 3 of the runbook.
6. Execute cleanup and verify the cluster is clean.

---

## Navigation

- [Back to Kubernetes Reference Architectures](../README.md)
- [Multi-Cluster Strategy Pattern](../multi-cluster-strategy/README.md)
- [HPA — Horizontal Pod Autoscaler](./hpa/README.md)
- [VPA — Vertical Pod Autoscaler](./vpa/README.md)
- [VPA Installation](./vpa/installation-vpa.md)
- [Autoscaling Runbook](./autoscaling-runbook.md)
