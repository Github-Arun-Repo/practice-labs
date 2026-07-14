#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Startup Probe — PROBLEM: slow app without startup probe ==="
echo ""
echo "This container takes 45 seconds to start."
echo "The liveness probe fires at t=5s and kills the pod by ~t=15s."
echo "The app never finishes starting. Watch the RESTARTS counter."
echo ""

kubectl apply -f "$BASE_DIR/startup-probe/k8s/namespace.yaml"
kubectl apply -f "$BASE_DIR/startup-probe/k8s/deployment-without-startup.yaml"

echo ""
echo "Deployed. Run 03-watch-startup.sh in another terminal to observe."
echo "Expected: pod enters a restart loop. RESTARTS increments every ~20 seconds."
