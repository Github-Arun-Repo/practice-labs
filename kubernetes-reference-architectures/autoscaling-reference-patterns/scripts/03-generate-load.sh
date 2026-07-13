#!/bin/bash
# 03-generate-load.sh — Start a load generator pod that hammers php-apache
# Run from: kubernetes-reference-architectures/autoscaling-reference-patterns/
#
# The php-apache app computes square roots on each request (CPU-intensive).
# This load generator sends continuous requests, driving CPU above the 50% HPA threshold.

echo "=== Starting load generator ==="
echo "Sending continuous HTTP requests to php-apache"
echo ""

# Remove any existing load generator first
kubectl delete pod load-generator -n autoscaling-demo --ignore-not-found 2>/dev/null
sleep 2

kubectl run load-generator \
  --image=busybox:1.36 \
  --namespace=autoscaling-demo \
  --restart=Never \
  --labels="purpose=load-test" \
  -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache.autoscaling-demo.svc.cluster.local; done"

echo ""
echo "Load generator pod is running."
echo "HPA will begin scaling up once average CPU crosses 50% of 200m = 100m."
echo ""
echo "Next step: run scripts/04-watch-hpa.sh to observe scaling in real time."
