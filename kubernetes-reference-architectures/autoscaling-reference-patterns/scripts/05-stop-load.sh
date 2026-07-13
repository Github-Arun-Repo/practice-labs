#!/bin/bash
# 05-stop-load.sh — Delete the load generator pod and observe HPA scale-down
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/

NAMESPACE="autoscaling-demo"

echo "=== Stopping load generator ==="
kubectl delete pod load-generator -n "$NAMESPACE" --ignore-not-found

echo ""
echo "Load generator removed."
echo ""
echo "HPA scale-down behavior:"
echo "  - Stabilization window: 60 seconds (demo-tuned)"
echo "  - After 60 seconds of low utilization, HPA will reduce replicas"
echo "  - Final replica count will return to minReplicas = 1"
echo ""
echo "Run scripts/04-watch-hpa.sh to observe the scale-down in real time."
echo "Expected timeline: replicas drop within 60-120 seconds."
