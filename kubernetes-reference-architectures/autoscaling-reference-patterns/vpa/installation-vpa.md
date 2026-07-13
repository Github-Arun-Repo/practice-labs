# Installing the Vertical Pod Autoscaler (VPA)

VPA is not part of the standard Kubernetes distribution. It must be installed separately before running the VPA section of the autoscaling runbook.

---

## Prerequisites

- Kubernetes cluster 1.24+
- kubectl with cluster access
- git installed locally
- OpenSSL (for certificate generation)

---

## Verify Whether VPA Is Already Installed

```bash
kubectl get crds | grep verticalpodautoscaler
kubectl get pods -n kube-system | grep vpa
```

If you see VPA CRDs and running VPA pods, VPA is already installed. Skip to the verification step.

---

## Installation via Official Script

```bash
# Clone the Kubernetes autoscaler repository
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler

# Run the VPA installation script
./hack/vpa-up.sh
```

This script:
1. Creates VPA CRDs (VerticalPodAutoscaler, VerticalPodAutoscalerCheckpoint)
2. Deploys vpa-recommender, vpa-updater, and vpa-admission-controller
3. Configures the MutatingWebhookConfiguration

---

## Verify Installation

```bash
kubectl get pods -n kube-system | grep vpa
```

Expected output:
```
vpa-admission-controller-xxxxx   1/1   Running   0   1m
vpa-recommender-xxxxx            1/1   Running   0   1m
vpa-updater-xxxxx                1/1   Running   0   1m
```

Verify the CRDs are registered:
```bash
kubectl get crds | grep verticalpodautoscaler
# Expected:
# verticalpodautoscalercheckpoints.autoscaling.k8s.io
# verticalpodautoscalers.autoscaling.k8s.io
```

---

## Alternative: Install via Helm

If you prefer Helm over the official script:

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update
helm install vpa fairwinds-stable/vpa \
  --namespace vpa \
  --create-namespace
```

Verify:
```bash
kubectl get pods -n vpa
```

---

## Uninstall VPA

Using the official script:
```bash
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-down.sh
```

Using Helm:
```bash
helm uninstall vpa -n vpa
kubectl delete namespace vpa
```

---

## Next Step

Return to the autoscaling runbook — Part 2 (VPA):

→ [autoscaling-runbook.md](../autoscaling-runbook.md)
