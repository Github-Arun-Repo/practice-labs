#!/bin/bash
# 07-watch-vpa.sh — Watch VPA recommendations and current pod resources in real time
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
# Ctrl+C to stop

NAMESPACE="autoscaling-demo"

echo "=== VPA Observer — refreshing every 30 seconds ==="
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "============================================"
  echo " VPA Observer | $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================"
  echo ""

  echo "--- VPA Objects ---"
  kubectl get vpa -n "$NAMESPACE" 2>/dev/null || echo "No VPA found (is VPA installed? see vpa/installation-vpa.md)"
  echo ""

  echo "--- VPA Recommendations (Lower Bound / Target / Upper Bound) ---"
  kubectl describe vpa -n "$NAMESPACE" 2>/dev/null | grep -A 20 "Recommendation:" \
    || echo "(No recommendations yet — wait 2-5 minutes after VPA is applied)"
  echo ""

  echo "--- Current Pod Resource Requests ---"
  kubectl get pod -n "$NAMESPACE" -l app=php-apache \
    -o custom-columns='POD:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory,CPU-LIM:.spec.containers[0].resources.limits.cpu,MEM-LIM:.spec.containers[0].resources.limits.memory' \
    2>/dev/null || echo "No php-apache pods found"
  echo ""

  echo "--- Resource Usage ---"
  kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "(metrics not available)"
  echo ""

  echo "[Refreshing in 30 seconds — Ctrl+C to stop]"
  sleep 30
done
