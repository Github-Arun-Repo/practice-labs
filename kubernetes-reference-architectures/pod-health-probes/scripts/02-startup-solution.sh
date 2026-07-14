#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Startup Probe — SOLUTION: same slow app, now with startup probe ==="
echo ""
echo "Startup probe allows 60 seconds (12 × 5s) for the app to initialize."
echo "Liveness and readiness are DISABLED until startup probe passes."
echo "Expected: RESTARTS stays at 0. Pod reaches Running/Ready after ~45 seconds."
echo ""

kubectl apply -f "$BASE_DIR/startup-probe/k8s/deployment-with-startup.yaml"

echo ""
echo "Deployed. Watch both pods side by side:"
echo "  kubectl get pods -n startup-demo -w"
echo ""
echo "slow-app-no-startup-probe  → RESTARTS keeps climbing"
echo "slow-app-with-startup-probe → RESTARTS stays at 0, reaches 1/1 Running"
