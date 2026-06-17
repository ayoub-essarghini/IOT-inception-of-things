#!/bin/bash

set -e

echo "Starting cleanup..."

echo "Killing port-forward processes..."
pkill -f "kubectl.*port-forward" || true
sleep 2

echo "Removing ALL k3d clusters..."
if command -v k3d >/dev/null 2>&1; then
  k3d cluster delete --all || true
fi

echo "Removing old k3d docker leftovers..."
docker rm -f $(docker ps -aq --filter "name=k3d-") 2>/dev/null || true
docker network rm $(docker network ls -q --filter "name=k3d-") 2>/dev/null || true

echo "Removing kubectl..."
sudo rm -f /usr/local/bin/kubectl

echo "Removing argocd cli..."
sudo rm -f /usr/local/bin/argocd

echo "Removing k3d..."
sudo rm -f /usr/local/bin/k3d

echo "Removing kubeconfig..."
rm -f "$HOME/.kube/config"

echo "Cleanup finished."