#!/usr/bin/env bash
set -euo pipefail

echo "=== Re-adding pod to service (readiness → ready) ==="
echo ""

POD=$(kubectl get pods -n readiness-demo -l app=readiness-demo \
  -o jsonpath='{.items[0].metadata.name}')

echo "Target pod: $POD"
echo ""
echo "Creating /tmp/ready — readiness probe will pass on next check (~5s)..."
kubectl exec "$POD" -n readiness-demo -- touch /tmp/ready

echo ""
echo "Waiting 10 seconds for readiness probe to register success..."
sleep 10

echo ""
echo "--- Pod status ---"
kubectl get pods -n readiness-demo -o wide

echo ""
echo "--- Service endpoints ---"
kubectl get endpoints readiness-demo -n readiness-demo

echo ""
echo "Note: All 3 pods are back to 1/1 READY. RESTARTS stayed at 0 throughout."
