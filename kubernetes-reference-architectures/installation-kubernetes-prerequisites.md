# Kubernetes Prerequisites and Tooling Validation

This section assumes Kubernetes is already installed and reachable.

You do not need cluster installation steps here. You only need to validate access and required tools before running the architecture demos.

---

## Prerequisites

- Running Kubernetes cluster (1.24+ recommended)
- kubectl configured with valid cluster context
- Metrics server optional but useful for capacity checks
- NetworkPolicy-capable CNI plugin (Calico, Cilium, Antrea, etc.)

---

## Validation Steps

### 1. Verify kubectl access

```bash
kubectl version --short
kubectl cluster-info
kubectl get nodes -o wide
```

### 2. Verify current context

```bash
kubectl config current-context
kubectl get ns
```

### 3. Verify NetworkPolicy support

```bash
kubectl api-resources | grep -i networkpolicy
```

### 4. Optional: Verify metrics and usage visibility

```bash
kubectl top nodes
kubectl top pods -A
```

If `kubectl top` is unavailable, install metrics server or continue without it.

---

## Assumptions for Current Pattern

The current pattern (`multi-cluster-strategy`) assumes:

- Shared Kubernetes cluster already exists
- Team namespaces are managed by platform manifests
- Guardrails are enforced via native Kubernetes resources

---

## Next Step

Proceed to:
- [Multi-Cluster Strategy README](./multi-cluster-strategy/README.md)
- [Multi-Cluster Runbook](./multi-cluster-strategy/multi-cluster-runbook.md)
