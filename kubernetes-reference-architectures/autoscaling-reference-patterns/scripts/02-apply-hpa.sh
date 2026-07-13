#!/bin/bash
# 02-apply-hpa.sh — Apply CPU-based HPA to php-apache
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
set -e

echo "=== Applying HPA (CPU-based, target 50% utilization) ==="
kubectl apply -f hpa/k8s/hpa-cpu.yaml

echo ""
echo "=== Waiting 15 seconds for HPA to initialize ==="
sleep 15

echo ""
echo "=== HPA Status ==="
kubectl get hpa php-apache-hpa-cpu -n autoscaling-demo

echo ""
echo "=== HPA Detail ==="
kubectl describe hpa php-apache-hpa-cpu -n autoscaling-demo

echo ""
echo "Note: TARGETS may show '<unknown>/50%' initially."
echo "This clears in 30-60 seconds once metrics-server provides readings."
