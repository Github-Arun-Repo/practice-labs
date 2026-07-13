# Kubernetes Autoscaling Reference Patterns — Runbook

**Repo:** `https://github.com/Github-Arun-Repo/platform-engineering-reference-architectures.git`
**Base folder:** `kubernetes-reference-architectures/autoscaling-reference-patterns/` (all commands below run from here)
**Cluster:** Standalone Kubernetes on EC2
**Presenter:** Arunasalam Govindasamy

---

## Repo Layout (all paths below match this)

```text
autoscaling-reference-patterns/
├── autoscaling-runbook.md              ← this file
├── sample-app/k8s/
│   ├── namespace.yaml                  # autoscaling-demo namespace
│   ├── deployment.yaml                 # php-apache (registry.k8s.io/hpa-example)
│   └── service.yaml                    # ClusterIP service
├── hpa/k8s/
│   ├── hpa-cpu.yaml                    # HPA — 50% CPU target, min 1 max 10
│   └── hpa-memory.yaml                 # HPA — 70% memory target (reference)
├── vpa/k8s/
│   ├── vpa-recommendation-only.yaml    # VPA Off mode — recommendations only
│   └── vpa-auto.yaml                   # VPA Auto mode — applies by restarting pods
└── scripts/
    ├── 00-cleanup.sh                   # full teardown
    ├── 01-deploy-sample-app.sh
    ├── 02-apply-hpa.sh
    ├── 03-generate-load.sh
    ├── 04-watch-hpa.sh
    ├── 05-stop-load.sh
    ├── 06-apply-vpa-recommendation.sh
    └── 07-watch-vpa.sh
```

---

## Prerequisites

**Part 1 (HPA) requires metrics-server:**
```bash
kubectl top nodes
```
If this fails, see [Metrics-Server Installation](#metrics-server-installation) below.

**Part 2 (VPA) requires VPA controller:**
```bash
kubectl get crds | grep verticalpodautoscaler
```
If no output, see [vpa/installation-vpa.md](./vpa/installation-vpa.md) before running Part 2.

---

## 0. PRE-FLIGHT

Run these checks before starting. Cluster must be accessible and scripts must be executable.

```bash
# Pull latest from repo root
cd ~/platform-engineering-reference-architectures && git pull

# Move into the working directory — all commands below run from here
cd kubernetes-reference-architectures/autoscaling-reference-patterns

# Make all scripts executable
chmod +x scripts/*.sh

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Verify metrics-server is working
kubectl top nodes
kubectl top pods -A | head -5

# CLEAN SLATE — remove any previous run
./scripts/00-cleanup.sh

echo "Ready."
```

**Timing plan:**
- Pre-flight and clean slate: ≈ 5 min
- Part 1 — HPA (CPU-based scaling): ≈ 30 min
- Part 2 — VPA (resource recommendations and auto-sizing): ≈ 25 min
- Part 3 — Failure scenarios: ≈ 15 min
- Reset and Q&A: ≈ 5 min
- **Total runbook time: ≈ 75 min**

---
---

# PART 1 — Horizontal Pod Autoscaler (≈30 min)

> **Goal:** Deploy a CPU-intensive application, apply HPA with a 50% CPU target, drive load above that threshold, and observe the cluster scale up and then scale down automatically.

---

## 1.1 — Deploy the Sample Application

The sample app is `registry.k8s.io/hpa-example` — the official Kubernetes HPA test application. It computes square roots on every HTTP request, making it CPU-intensive by design.

```bash
./scripts/01-deploy-sample-app.sh
```

👉 One pod running. Resource requests confirmed at `200m` CPU. This is the baseline.

Verify manually:
```bash
kubectl get pods -n autoscaling-demo
kubectl get svc -n autoscaling-demo
kubectl describe deployment php-apache -n autoscaling-demo | grep -A 5 "Requests:"
```

---

## 1.2 — Baseline: No HPA, Check Low CPU

Before applying HPA, confirm what idle CPU looks like.

```bash
# Wait 60 seconds after deployment, then check
kubectl top pods -n autoscaling-demo
```

👉 CPU usage is minimal — a few millicores. The deployment is idle. No autoscaler is watching.

```bash
kubectl get hpa -n autoscaling-demo
# Expected: No resources found in autoscaling-demo namespace.
```

---

## 1.3 — Apply HPA and Understand the Initial State

```bash
./scripts/02-apply-hpa.sh
```

```bash
kubectl get hpa -n autoscaling-demo
# NAME                   REFERENCE           TARGETS        MINPODS   MAXPODS   REPLICAS
# php-apache-hpa-cpu     Deployment/php-apache   <unknown>/50%   1         10        1
```

👉 `TARGETS` shows `<unknown>/50%` initially. This is expected. The HPA controller is waiting for its first metrics-server reading (happens within 60 seconds).

Wait 60 seconds and re-check:
```bash
kubectl get hpa -n autoscaling-demo
# Expected: TARGETS shows something like   2%/50%   — idle CPU is well below threshold
```

👉 `2%/50%` means actual CPU is 2% of the 200m request (≈ 4m). Target is 50% (100m). HPA holds at 1 replica.

**The HPA scaling algorithm in this state:**
```
desiredReplicas = ceil[ 1 × (2 ÷ 50) ] = ceil[0.04] = 1
```
Result: no change. HPA correctly stays at minReplicas = 1.

---

## 1.4 — Generate CPU Load

In a **separate terminal** (or background), start the load generator:

```bash
./scripts/03-generate-load.sh
```

This launches a `busybox` pod that sends continuous HTTP requests to `php-apache` every 10ms. Each request triggers a CPU-intensive square root computation.

```bash
# Confirm the load generator is running
kubectl get pods -n autoscaling-demo
# Expected: Both php-apache and load-generator pods running
```

---

## 1.5 — Observe HPA Scale-Up in Real Time

In your **main terminal**, start the watcher:

```bash
./scripts/04-watch-hpa.sh
```

Watch the following sequence over 1-3 minutes:

```
--- HPA Status ---
NAME                 TARGETS      MINPODS  MAXPODS  REPLICAS
php-apache-hpa-cpu   248%/50%     1        10       1
```

👉 CPU has spiked to 248% of the 200m request. The scaling calculation:
```
desiredReplicas = ceil[ 1 × (248 ÷ 50) ] = ceil[4.96] = 5
```

HPA instructs the Deployment to scale to 5 replicas.

```
--- Pod Count ---
Running php-apache pods: 5
```

👉 5 pods running. Load is now distributed across 5 replicas. Average CPU per pod drops.

```
--- HPA Status ---
NAME                 TARGETS      MINPODS  MAXPODS  REPLICAS
php-apache-hpa-cpu   52%/50%      1        10       5
```

👉 HPA has reached equilibrium. 5 replicas holding average CPU near the 50% target.

---

## 1.6 — Test Max Replicas Ceiling

With load still running, try to force more replicas than maxReplicas allows.

```bash
kubectl get hpa php-apache-hpa-cpu -n autoscaling-demo -o yaml | grep maxReplicas
# maxReplicas: 10

# Even under extreme load, HPA will not go above 10
# Add more concurrent load generators to observe the ceiling:
kubectl run load-generator-2 \
  --image=busybox:1.36 \
  --namespace=autoscaling-demo \
  --restart=Never \
  --labels="purpose=load-test" \
  -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache.autoscaling-demo.svc.cluster.local; done"
```

```bash
kubectl get hpa -n autoscaling-demo
# REPLICAS column will reach 10 and stop there even if CPU remains high
```

👉 REPLICAS = 10 and stays at 10. HPA respects the ceiling even with high CPU demand.

```bash
# Remove the extra load generator
kubectl delete pod load-generator-2 -n autoscaling-demo --ignore-not-found
```

---

## 1.7 — Stop Load and Observe Scale-Down

```bash
# In the watcher terminal — press Ctrl+C to stop watching
# In the main terminal:
./scripts/05-stop-load.sh
```

Then restart the watcher:
```bash
./scripts/04-watch-hpa.sh
```

Watch the scale-down sequence:

```
--- HPA Status (immediately after stopping load) ---
TARGETS: 0%/50%     REPLICAS: 5
```

👉 CPU has dropped to near zero. HPA detects this but waits for the stabilization window (60 seconds in this config) before acting.

After ~60-90 seconds:
```
--- HPA Status ---
TARGETS: 0%/50%     REPLICAS: 1
```

👉 Back to 1 replica. HPA has scaled down. The stabilization window prevents flapping during brief traffic dips.

**Press Ctrl+C on the watcher.**

---

## 1.8 — Verify Min Replicas Protection

With no load and no HPA changes:

```bash
# Try to manually scale below minReplicas
kubectl scale deployment php-apache --replicas=0 -n autoscaling-demo
sleep 30
kubectl get pods -n autoscaling-demo
```

👉 Pods may briefly hit 0 but HPA will restore to minReplicas = 1 within the next sync interval (15 seconds).

```bash
kubectl get hpa php-apache-hpa-cpu -n autoscaling-demo
# REPLICAS will return to 1 — HPA enforces the minimum
```

---

**Part 1 Summary:**
HPA reads CPU metrics every 15 seconds, applies the scaling formula, and adjusts replicas within min/max bounds. Scale-up is immediate; scale-down waits for the stabilization window to confirm the load has genuinely decreased. Resource requests on the container are mandatory — HPA cannot calculate utilization without them.

---
---

# PART 2 — Vertical Pod Autoscaler (≈25 min)

> **Goal:** Apply VPA in recommendation-only mode to observe what resource allocation the workload actually needs, then apply VPA in Auto mode to see pods restarted with updated resource values.

> **Prerequisite:** VPA must be installed. Check with `kubectl get crds | grep verticalpodautoscaler`. If not installed, follow [vpa/installation-vpa.md](./vpa/installation-vpa.md) and return here.

---

## 2.1 — Remove HPA Before Applying VPA

HPA and VPA on the same resource dimension conflict. Remove the CPU HPA before applying VPA.

```bash
kubectl delete hpa php-apache-hpa-cpu -n autoscaling-demo --ignore-not-found
kubectl get hpa -n autoscaling-demo
# Expected: No resources found
```

---

## 2.2 — Apply VPA in Recommendation-Only Mode (Off)

```bash
./scripts/06-apply-vpa-recommendation.sh
```

```bash
kubectl get vpa -n autoscaling-demo
# NAME                         MODE   CPU    MEM       PROVIDED   AGE
# php-apache-vpa-recommender   Off    <n/a>  <n/a>     False      10s
```

👉 VPA object exists. `PROVIDED: False` means no recommendations yet. The recommender needs a few minutes of data.

Wait 2-3 minutes, then:
```bash
kubectl describe vpa php-apache-vpa-recommender -n autoscaling-demo
```

Look for the `Recommendation` section:
```yaml
Recommendation:
  Container Recommendations:
    Container Name:  php-apache
    Lower Bound:
      Cpu:     25m
      Memory:  262144k
    Target:
      Cpu:     25m
      Memory:  262144k
    Uncapped Target:
      Cpu:     25m
      Memory:  262144k
    Upper Bound:
      Cpu:     793m
      Memory:  907M
```

👉 VPA recommends `25m` CPU vs your current request of `200m`. The workload was idle so VPA sees low usage and recommends a lower target value. This is correct right-sizing data.

---

## 2.3 — Start the VPA Watcher

```bash
./scripts/07-watch-vpa.sh
```

Leave this running in a split terminal.

---

## 2.4 — Generate Load and Watch Recommendations Change

In the main terminal, generate load while VPA is watching:

```bash
./scripts/03-generate-load.sh
```

Wait 3-5 minutes. VPA collects data during load. Check recommendations again:

```bash
kubectl describe vpa php-apache-vpa-recommender -n autoscaling-demo | grep -A 20 "Recommendation:"
```

👉 Target CPU recommendation increases as VPA observes the elevated usage. This is the key VPA behavior: it learns over time and adjusts recommendations based on what the workload actually consumes.

Stop the load:
```bash
./scripts/05-stop-load.sh
```

---

## 2.5 — Switch VPA to Auto Mode

Now switch from observation to action. In Auto mode, VPA will restart pods with updated resource values.

```bash
# Remove the Off-mode VPA
kubectl delete vpa php-apache-vpa-recommender -n autoscaling-demo --ignore-not-found

# Apply Auto-mode VPA
kubectl apply -f vpa/k8s/vpa-auto.yaml
kubectl get vpa -n autoscaling-demo
```

```bash
# Record current pod name and resources before VPA acts
kubectl get pod -n autoscaling-demo -l app=php-apache \
  -o custom-columns='POD:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory'
```

👉 Current pod was created with `cpu: 200m, memory: 256Mi` — the values from the Deployment manifest.

Wait 2-3 minutes for the VPA updater to act, then:

```bash
kubectl get pod -n autoscaling-demo -l app=php-apache \
  -o custom-columns='POD:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory'
```

👉 A NEW pod name — the old pod was evicted and recreated. The new pod has different CPU and memory requests set by VPA based on its recommendations.

```bash
# Also observe the events on the deployment
kubectl get events -n autoscaling-demo --sort-by='.lastTimestamp' | tail -10
```

👉 Events show `EvictedForVPA` or similar — VPA triggered the pod restart.

---

## 2.6 — The Safe HPA + VPA Combination

To run HPA (scale pods) and VPA (right-size pods) together without conflict:

```bash
# VPA controls memory only
kubectl apply -f - <<'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: php-apache-vpa-memory-only
  namespace: autoscaling-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: php-apache
        controlledResources: ["memory"]   # VPA only touches memory
        minAllowed:
          memory: 64Mi
        maxAllowed:
          memory: 2Gi
EOF

# HPA controls CPU
kubectl apply -f hpa/k8s/hpa-cpu.yaml

kubectl get hpa,vpa -n autoscaling-demo
```

👉 HPA scales replica count based on CPU. VPA adjusts memory allocation per pod. No conflict.

---

**Part 2 Summary:**
VPA in Off mode is your right-sizing advisor — safe to run in production immediately. VPA in Auto mode actively resizes pods by restarting them. Always restrict VPA to specific resources when HPA is also active. Give VPA at least 5-10 minutes of load data before trusting its recommendations.

---
---

# PART 3 — Failure Scenarios (≈15 min)

> **Goal:** Understand what happens when common configuration mistakes are made. Each scenario shows the failure, explains why it happens, and shows the fix.

---

## 3.1 — HPA Without metrics-server

**What happens:** HPA cannot read CPU metrics. It shows `<unknown>` and cannot scale.

```bash
# Simulate by checking HPA status when metrics-server is unavailable or not ready
kubectl delete hpa php-apache-hpa-cpu -n autoscaling-demo --ignore-not-found
kubectl apply -f hpa/k8s/hpa-cpu.yaml
kubectl get hpa -n autoscaling-demo
```

If metrics-server is down or not installed, the TARGETS column will show:
```
NAME                 TARGETS         REPLICAS
php-apache-hpa-cpu   <unknown>/50%   1
```

And the Events section will show:
```bash
kubectl describe hpa php-apache-hpa-cpu -n autoscaling-demo | grep -A 5 "Events:"
# Warning  FailedGetResourceMetric  metrics server is not yet available
```

**Fix:**
```bash
# Verify metrics-server is running
kubectl get pods -n kube-system | grep metrics-server

# If not running or certificate errors, patch it:
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait 60 seconds then verify
kubectl top nodes
kubectl get hpa -n autoscaling-demo
```

---

## 3.2 — HPA Without Resource Requests on the Pod

**What happens:** HPA cannot calculate CPU utilization percentage because there is no request to compare against.

```bash
# Apply a deployment with no resource requests
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-no-requests
  namespace: autoscaling-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-no-requests
  template:
    metadata:
      labels:
        app: php-no-requests
    spec:
      containers:
        - name: app
          image: registry.k8s.io/hpa-example
          ports:
            - containerPort: 80
          # NOTE: No resources.requests defined — intentional for this failure test
EOF

# Apply HPA against this deployment
kubectl apply -f - <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-no-requests-hpa
  namespace: autoscaling-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-no-requests
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF

sleep 30
kubectl describe hpa php-no-requests-hpa -n autoscaling-demo | grep -A 5 "Events:"
```

👉 HPA will show a warning: `failed to get cpu utilization: missing request for cpu`.

**Fix:** Always define resource requests on containers that use HPA.

Cleanup this test:
```bash
kubectl delete hpa php-no-requests-hpa -n autoscaling-demo --ignore-not-found
kubectl delete deployment php-no-requests -n autoscaling-demo --ignore-not-found
```

---

## 3.3 — VPA and HPA Conflict on Same Resource

**What happens:** HPA scales up replicas to handle load. VPA simultaneously evicts the same pods to resize resources. The cluster oscillates — new pods appear, get evicted, get scaled, get evicted again.

This is not demonstrated destructively, but here is what to look for if you accidentally apply both:

```bash
# Symptoms:
# - Pods constantly restarting
# - HPA replica count fluctuating up and down unexpectedly
# - Events showing EvictedForVPA followed immediately by scale-up events

kubectl get events -n autoscaling-demo --sort-by='.lastTimestamp' | grep -E "Evict|Scaled"
```

**Fix:** Remove either the HPA or restrict VPA to only control the other resource:

```bash
# Option A: Remove HPA, let VPA control everything
kubectl delete hpa --all -n autoscaling-demo

# Option B: Restrict VPA to memory only, let HPA handle CPU
kubectl delete vpa php-apache-vpa-auto -n autoscaling-demo --ignore-not-found
kubectl apply -f vpa/k8s/vpa-recommendation-only.yaml  # safer — Off mode
```

---

## 3.4 — Scale-Down Too Aggressive (Flapping)

**What happens:** With a very short stabilization window, brief traffic dips cause premature scale-down and then immediate scale-up again. Pods are repeatedly created and destroyed.

The default Kubernetes stabilization window of 300 seconds prevents this. Our demo-tuned value of 60 seconds is visible as faster scale-down.

To observe flapping at an extreme level:

```bash
# Apply an HPA with no stabilization window
kubectl apply -f - <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache-hpa-aggressive
  namespace: autoscaling-demo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 0    # no cooldown at all — will flap
EOF

# Generate and then stop load repeatedly, watch pods bounce
./scripts/03-generate-load.sh
sleep 30
./scripts/05-stop-load.sh
./scripts/04-watch-hpa.sh
```

👉 Replicas jump up and down rapidly. This is the flapping problem that stabilization windows prevent.

Cleanup:
```bash
kubectl delete hpa php-apache-hpa-aggressive -n autoscaling-demo --ignore-not-found
```

---

## 3.5 — HPA Scale-Down Blocked by PodDisruptionBudget

If a PodDisruptionBudget (PDB) is configured to require minimum available pods, HPA scale-down can be blocked when current replicas are close to the minimum available threshold.

```bash
# Create a PDB that requires all replicas to be available
kubectl apply -f - <<'EOF'
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: php-apache-pdb
  namespace: autoscaling-demo
spec:
  minAvailable: "100%"
  selector:
    matchLabels:
      app: php-apache
EOF

# Now try to scale down
kubectl scale deployment php-apache --replicas=1 -n autoscaling-demo
kubectl get events -n autoscaling-demo --sort-by='.lastTimestamp' | tail -5
```

👉 Events show eviction blocked by PDB. HPA respects disruption budgets — it won't forcibly remove pods if the PDB would be violated.

Cleanup:
```bash
kubectl delete pdb php-apache-pdb -n autoscaling-demo --ignore-not-found
```

---

# RESET (after runbook / to execute again)

```bash
# Stop any running watchers first (Ctrl+C in their terminals)

# Full cleanup
./scripts/00-cleanup.sh

# Verify clean state
kubectl get ns | grep autoscaling
kubectl get hpa -A | grep autoscaling
kubectl get vpa -A | grep autoscaling 2>/dev/null || true

# Optional: reset Git state if deployment.yaml was modified
git checkout sample-app/k8s/deployment.yaml
git checkout hpa/k8s/hpa-cpu.yaml

echo "Ready for next run."
```

---

## Metrics-Server Installation

If `kubectl top nodes` fails, install metrics-server:

```bash
# Standard installation
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For EC2 / self-managed clusters with self-signed kubelet certificates:
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Verify (wait 60 seconds after installation)
kubectl rollout status deployment/metrics-server -n kube-system
kubectl top nodes
```

---

## Command Cheat-Sheet

| Intent | Command |
|---|---|
| Deploy sample app | `./scripts/01-deploy-sample-app.sh` |
| Apply HPA (CPU 50%) | `./scripts/02-apply-hpa.sh` |
| Start load generator | `./scripts/03-generate-load.sh` |
| Watch HPA in real time | `./scripts/04-watch-hpa.sh` |
| Stop load generator | `./scripts/05-stop-load.sh` |
| Apply VPA (Off mode) | `./scripts/06-apply-vpa-recommendation.sh` |
| Watch VPA recommendations | `./scripts/07-watch-vpa.sh` |
| Full cleanup | `./scripts/00-cleanup.sh` |
| Get HPA status | `kubectl get hpa -n autoscaling-demo` |
| Get HPA detail | `kubectl describe hpa php-apache-hpa-cpu -n autoscaling-demo` |
| Get VPA recommendations | `kubectl describe vpa -n autoscaling-demo` |
| Check resource usage | `kubectl top pods -n autoscaling-demo` |
| Check pod resources | `kubectl get pod -n autoscaling-demo -l app=php-apache -o custom-columns='NAME:.metadata.name,CPU:.spec.containers[0].resources.requests.cpu,MEM:.spec.containers[0].resources.requests.memory'` |
| Check events | `kubectl get events -n autoscaling-demo --sort-by='.lastTimestamp'` |

---

## Key Points to Reinforce

1. **HPA scales replicas — VPA right-sizes each replica.** They solve different problems.
2. **Resource requests are mandatory for HPA.** Without them, HPA cannot compute utilization.
3. **Scale-up is fast; scale-down is deliberately slow.** The stabilization window prevents flapping.
4. **VPA Off mode is always safe.** It never touches running pods. Use it to get recommendations first.
5. **VPA Auto mode restarts pods.** It evicts and recreates them. Plan for this in production.
6. **Do not run HPA and VPA on the same resource.** Use HPA for CPU and VPA for memory if both are needed.
7. **metrics-server is required for both.** Neither HPA nor VPA can operate without resource usage data.
