#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Combined Probe Demo — all three probes on one deployment ==="
echo ""
echo "Startup probe:   30-second startup window (nginx starts fast, but configured safely)"
echo "Liveness probe:  HTTP check every 10s — detects a dead process"
echo "Readiness probe: file check every 5s  — controls traffic independently"
echo ""

kubectl apply -f "$BASE_DIR/combined/k8s/namespace.yaml"
kubectl apply -f "$BASE_DIR/combined/k8s/deployment.yaml"
kubectl apply -f "$BASE_DIR/combined/k8s/service.yaml"

echo ""
echo "Waiting for pods to be ready..."
kubectl rollout status deployment/combined-demo -n combined-demo --timeout=60s

echo ""
kubectl get pods -n combined-demo -o wide
echo ""

echo "Inspect probe configuration on a running pod:"
POD=$(kubectl get pods -n combined-demo -l app=combined-demo \
  -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n combined-demo \
  -o jsonpath='{range .spec.containers[*]}Probes for {.name}:{"\n"}  startup:   {.startupProbe}{"\n"}  liveness:  {.livenessProbe}{"\n"}  readiness: {.readinessProbe}{"\n"}{end}'
echo ""
