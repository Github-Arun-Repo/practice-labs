# Multi-Cluster Strategy Runbook (Shared Cluster Multi-Tenancy)

**Repo:** `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
**Base folder:** `kubernetes-reference-architectures/multi-cluster-strategy/`
**Assumption:** Kubernetes is already installed and reachable.

---

## Timing Plan

- Pre-flight checks and context validation: 5 minutes
- Pattern deployment and resource verification: 10-12 minutes
- Baseline checks (limits, service accounts, quotas): 8-10 minutes
- Failure tests and policy validation: 18-22 minutes
- Cleanup and post-check: 3-5 minutes
- **Total expected duration:** 45-55 minutes

---

## What You Will Demonstrate

- Namespace isolation
- Resource quotas
- Default CPU and memory limits
- RBAC per team
- Network isolation
- Service account boundaries
- Secrets separation

You will also run failure tests to prove that guardrails actually enforce isolation.

---

## Repo Layout

```text
multi-cluster-strategy/
├── README.md
├── multi-cluster-runbook.md
└── k8s/shared-cluster/
    ├── kustomization.yaml
    ├── team-a/
    └── team-b/
```

---

## 0. Pre-Flight

```bash
cd ~/projects/platform-engineering-reference-architectures
kubectl config current-context
kubectl get nodes
kubectl api-resources | grep -i networkpolicy
```

If NetworkPolicy is not supported by your CNI plugin, network isolation tests will not be enforceable.

---

## 1. Deploy The Pattern

```bash
cd kubernetes-reference-architectures/multi-cluster-strategy
kubectl apply -k k8s/shared-cluster
```

Validate resources:

```bash
kubectl get ns team-a team-b
kubectl get resourcequota,limitrange -n team-a
kubectl get resourcequota,limitrange -n team-b
kubectl get sa,role,rolebinding -n team-a
kubectl get sa,role,rolebinding -n team-b
kubectl get networkpolicy -n team-a
kubectl get networkpolicy -n team-b
kubectl get secret -n team-a
kubectl get secret -n team-b
kubectl get deploy,svc -n team-a
kubectl get deploy,svc -n team-b
```

---

## 2. Baseline Checks

### 2.1 Namespace isolation

```bash
kubectl get pods -n team-a
kubectl get pods -n team-b
```

### 2.2 Default CPU and memory limits (LimitRange)

The deployments intentionally omit explicit resource blocks. Kubernetes should inject defaults from each namespace LimitRange.

```bash
kubectl get pod -n team-a -l app=team-a-demo -o jsonpath='{.items[0].spec.containers[0].resources}'
echo
kubectl get pod -n team-b -l app=team-b-demo -o jsonpath='{.items[0].spec.containers[0].resources}'
echo
```

### 2.3 Service account attachment

```bash
kubectl get pod -n team-a -l app=team-a-demo -o jsonpath='{.items[0].spec.serviceAccountName}'
echo
kubectl get pod -n team-b -l app=team-b-demo -o jsonpath='{.items[0].spec.serviceAccountName}'
echo
```

---

## 3. Failure Tests (Required)

### Test 1: Can Team A access Team B resources?

Expected: **No**

```bash
kubectl auth can-i get deployments -n team-b --as=system:serviceaccount:team-a:team-a-automation
kubectl auth can-i list secrets -n team-b --as=system:serviceaccount:team-a:team-a-automation
```

Expected output: `no`

### Test 2: Can one namespace consume the entire cluster?

Expected: **No, blocked by ResourceQuota/LimitRange**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-a-quota-breaker
  namespace: team-a
spec:
  replicas: 20
  selector:
    matchLabels:
      app: team-a-quota-breaker
  template:
    metadata:
      labels:
        app: team-a-quota-breaker
    spec:
      containers:
        - name: stress
          image: busybox:1.36
          command: ["sh", "-c", "sleep 3600"]
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "1"
              memory: "1Gi"
EOF
```

Expected: admission error about exceeded quota or pending pods due quota constraints.

Cleanup:

```bash
kubectl delete deployment team-a-quota-breaker -n team-a --ignore-not-found
```

### Test 3: Can an unauthorized user delete another team's deployment?

Expected: **No**

```bash
kubectl auth can-i delete deployment/team-b-demo -n team-b --as=system:serviceaccount:team-a:team-a-automation
kubectl --as=system:serviceaccount:team-a:team-a-automation -n team-b delete deployment team-b-demo
```

Expected output: `no` and `forbidden`.

### Test 4: Can one application connect to another namespace unexpectedly?

Expected: **No, blocked by NetworkPolicy default deny**

```bash
kubectl -n team-a run net-debug --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 300
kubectl -n team-a wait --for=condition=Ready pod/net-debug --timeout=120s
kubectl -n team-a exec net-debug -- curl -m 5 -sS team-b-demo.team-b.svc.cluster.local
```

Expected: connection timeout or blocked traffic.

Cleanup:

```bash
kubectl -n team-a delete pod net-debug --ignore-not-found
```

---

## 4. Secrets Separation Checks

### Team A service account cannot read Team B secrets

```bash
kubectl auth can-i get secret/team-b-app-secret -n team-b --as=system:serviceaccount:team-a:team-a-automation
```

Expected output: `no`

### Team B service account cannot read Team A secrets

```bash
kubectl auth can-i get secret/team-a-app-secret -n team-a --as=system:serviceaccount:team-b:team-b-automation
```

Expected output: `no`

---

## 5. Clean Up

```bash
kubectl delete -k k8s/shared-cluster
```

---

## Operational Notes

1. Namespace-only isolation is not enough; enforce identity, quotas, and network controls together.
2. Guardrails should be tested with failure scenarios, not assumed.
3. This baseline is a prerequisite before introducing true multi-cluster segmentation.
