#!/usr/bin/env bash

echo "=== Watching Startup Probe Demo — Ctrl+C to stop ==="
echo ""
echo "Compare RESTARTS and READY columns for both pods."
echo ""

while true; do
  clear
  echo "--- Pods ---"
  kubectl get pods -n startup-demo -o wide 2>/dev/null || echo "(namespace not yet created)"
  echo ""
  echo "--- Events (last 5) ---"
  kubectl get events -n startup-demo --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || true
  echo ""
  sleep 5
done
