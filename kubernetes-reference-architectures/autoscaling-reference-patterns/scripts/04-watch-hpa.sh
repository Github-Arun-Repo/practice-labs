#!/bin/bash
# 04-watch-hpa.sh — Watch HPA replicas, pod count, and CPU usage in real time
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
# Ctrl+C to stop watching

NAMESPACE="autoscaling-demo"

echo "=== HPA Observer — refreshing every 15 seconds ==="
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "============================================"
  echo " HPA Observer | $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================"
  echo ""

  echo "--- HPA Status ---"
  kubectl get hpa -n "$NAMESPACE" -o wide 2>/dev/null || echo "No HPA found in $NAMESPACE"
  echo ""

  echo "--- Pod Count ---"
  POD_COUNT=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | grep php-apache | wc -l)
  echo "Running php-apache pods: $POD_COUNT"
  kubectl get pods -n "$NAMESPACE" 2>/dev/null
  echo ""

  echo "--- CPU / Memory Usage ---"
  kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "(metrics not yet available — wait 60s after deploying)"
  echo ""

  echo "[Refreshing in 15 seconds — Ctrl+C to stop]"
  sleep 15
done
