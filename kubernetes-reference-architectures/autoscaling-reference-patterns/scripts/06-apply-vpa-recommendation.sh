#!/bin/bash
# 06-apply-vpa-recommendation.sh — Apply VPA in Off mode (recommendations only, no pod restarts)
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
set -e

NAMESPACE="autoscaling-demo"

echo "=== Removing CPU HPA to avoid VPA conflict ==="
kubectl delete hpa php-apache-hpa-cpu -n "$NAMESPACE" --ignore-not-found

echo ""
echo "=== Applying VPA in recommendation-only mode (updateMode: Off) ==="
kubectl apply -f vpa/k8s/vpa-recommendation-only.yaml

echo ""
echo "VPA applied. The recommender collects resource usage data over time."
echo "Wait 2-5 minutes for recommendations to populate."
echo ""
echo "To check recommendations:"
echo "  kubectl describe vpa php-apache-vpa-recommender -n $NAMESPACE"
echo ""
echo "Or run: scripts/07-watch-vpa.sh"
