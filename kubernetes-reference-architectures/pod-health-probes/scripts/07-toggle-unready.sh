#!/usr/bin/env bash
set -euo pipefail

echo "=== Removing one pod from service (readiness → unready) ==="
echo ""

POD=$(kubectl get pods -n readiness-demo -l app=readiness-demo \
  -o jsonpath='{.items[0].metadata.name}')

echo "Target pod: $POD"
echo ""
echo "Deleting /tmp/ready — readiness probe will fail on next check (~5s)..."
kubectl exec "$POD" -n readiness-demo -- rm -f /tmp/ready

echo ""
echo "Waiting 15 seconds for readiness probe to register failure..."
sleep 15

echo ""
echo "--- Pod status ---"
kubectl get pods -n readiness-demo -o wide

echo ""
echo "--- Service endpoints ---"
kubectl get endpoints readiness-demo -n readiness-demo

echo ""
echo "Note: $POD shows 0/1 READY but RESTARTS is still 0."
echo "The pod is alive and the process is running — just not in service."
echo "Traffic continues on the other 2 pods."
