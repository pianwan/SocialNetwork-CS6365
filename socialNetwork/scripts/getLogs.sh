#!/bin/bash

echo -e "\e[33mGet logs of each container\e[0m"

NAMESPACE="social-network"
LOCAL_TMP_DIR="/tmp/"

pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

for pod in $pods; do
  containers=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}')
  for container in $containers; do
    echo "Fetching logs from pod=$pod, container=$container"
    kubectl logs -n $NAMESPACE $pod -c $container > "$LOCAL_TMP_DIR/log_${container}.log" 2>&1
  done
done