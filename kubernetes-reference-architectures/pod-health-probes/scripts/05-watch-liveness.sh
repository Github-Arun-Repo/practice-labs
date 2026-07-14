#!/usr/bin/env bash

echo "=== Watching Liveness Probe — Ctrl+C to stop ==="
echo ""
echo "liveness-demo: RESTARTS should increment every ~30 seconds."
echo "liveness-anti-pattern: RESTARTS stays at 0 until /tmp/healthy is deleted."
echo ""

while true; do
  clear
  echo "--- Pods ---"
  kubectl get pods -n liveness-demo -o wide 2>/dev/null || echo "(namespace not yet created)"
  echo ""
  echo "--- Recent Events ---"
  kubectl get events -n liveness-demo --sort-by='.lastTimestamp' 2>/dev/null | tail -8 || true
  echo ""
  sleep 5
done
