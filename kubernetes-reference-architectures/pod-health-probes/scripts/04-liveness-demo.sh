#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Liveness Probe Demo ==="
echo ""
echo "Deploying two pods:"
echo "  liveness-demo         → correct use: auto-restart when app is stuck"
echo "  liveness-anti-pattern → wrong use:   restart when external dep goes down"
echo ""

kubectl apply -f "$BASE_DIR/liveness-probe/k8s/namespace.yaml"
kubectl apply -f "$BASE_DIR/liveness-probe/k8s/deployment.yaml"
kubectl apply -f "$BASE_DIR/liveness-probe/k8s/deployment-anti-pattern.yaml"

echo ""
echo "Waiting for pods to start..."
sleep 10
kubectl get pods -n liveness-demo -o wide

echo ""
echo "Run 05-watch-liveness.sh to observe liveness-demo restart loop."
echo "After watching, run the anti-pattern demo from the runbook."
