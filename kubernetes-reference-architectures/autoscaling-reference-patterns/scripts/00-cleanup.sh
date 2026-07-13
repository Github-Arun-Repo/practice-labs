#!/bin/bash
# cleanup.sh — Remove everything created by this autoscaling reference pattern
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
set -e

NAMESPACE="autoscaling-demo"

echo "=== Full cleanup of autoscaling-reference-patterns ==="
echo ""

echo "[1/6] Removing load generator pod..."
kubectl delete pod load-generator -n "$NAMESPACE" --ignore-not-found

echo "[2/6] Removing HPA..."
kubectl delete hpa --all -n "$NAMESPACE" --ignore-not-found

echo "[3/6] Removing VPA..."
kubectl delete vpa --all -n "$NAMESPACE" --ignore-not-found 2>/dev/null || echo "  (VPA CRD not installed or no VPA objects found)"

echo "[4/6] Removing deployment and service..."
kubectl delete deployment php-apache -n "$NAMESPACE" --ignore-not-found
kubectl delete service php-apache -n "$NAMESPACE" --ignore-not-found

echo "[5/6] Removing any lingering stress test pods..."
kubectl delete pod -n "$NAMESPACE" -l purpose=load-test --ignore-not-found

echo "[6/6] Removing namespace..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found

echo ""
echo "=== Cleanup complete ==="
