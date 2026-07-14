#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Readiness Probe Demo ==="
echo ""
echo "Deploying 3 replicas with a file-based readiness probe."
echo "A postStart hook creates /tmp/ready so all pods start in service."
echo ""

kubectl apply -f "$BASE_DIR/readiness-probe/k8s/namespace.yaml"
kubectl apply -f "$BASE_DIR/readiness-probe/k8s/deployment.yaml"
kubectl apply -f "$BASE_DIR/readiness-probe/k8s/service.yaml"

echo ""
echo "Waiting for pods to be ready..."
kubectl rollout status deployment/readiness-demo -n readiness-demo --timeout=60s

echo ""
kubectl get pods -n readiness-demo -o wide
echo ""
echo "All 3 pods are Ready and in service endpoints."
echo ""
echo "Next steps:"
echo "  Run 07-toggle-unready.sh to remove one pod from service (no restart)"
echo "  Run 08-toggle-ready.sh   to add it back"
