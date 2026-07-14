#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning up all probe demo namespaces ==="
echo ""

kubectl delete namespace startup-demo --ignore-not-found
kubectl delete namespace liveness-demo --ignore-not-found
kubectl delete namespace readiness-demo --ignore-not-found
kubectl delete namespace combined-demo --ignore-not-found

echo ""
echo "Waiting for namespaces to terminate..."
kubectl wait --for=delete namespace/startup-demo --timeout=60s 2>/dev/null || true
kubectl wait --for=delete namespace/liveness-demo --timeout=60s 2>/dev/null || true
kubectl wait --for=delete namespace/readiness-demo --timeout=60s 2>/dev/null || true
kubectl wait --for=delete namespace/combined-demo --timeout=60s 2>/dev/null || true

echo ""
echo "Done. All probe demo namespaces removed."
