#!/bin/bash
# 01-deploy-sample-app.sh — Deploy the php-apache sample application
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
set -e

echo "=== Deploying sample application: php-apache ==="
echo "Image: registry.k8s.io/hpa-example"
echo "Namespace: autoscaling-demo"
echo ""

kubectl apply -f sample-app/k8s/namespace.yaml
kubectl apply -f sample-app/k8s/deployment.yaml
kubectl apply -f sample-app/k8s/service.yaml

echo ""
echo "=== Waiting for deployment to become ready (up to 120s) ==="
kubectl rollout status deployment/php-apache -n autoscaling-demo --timeout=120s

echo ""
echo "=== Deployment complete ==="
kubectl get pods -n autoscaling-demo
echo ""
kubectl get svc -n autoscaling-demo
echo ""
echo "CPU/memory requests on the pod (needed for HPA to work):"
kubectl get pod -n autoscaling-demo -l app=php-apache \
  -o jsonpath='{range .items[*]}{.metadata.name}{": cpu="}{.spec.containers[0].resources.requests.cpu}{" mem="}{.spec.containers[0].resources.requests.memory}{"\n"}{end}'
