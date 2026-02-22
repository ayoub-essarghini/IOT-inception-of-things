#!/bin/bash

echo "Starting cleanup..."

# kill any port-forward processes
echo "Killing port-forward processes..."
pkill -f "kubectl.*port-forward" || true
sleep 2

# remove k3d cluster
echo "Removing k3d cluster..."
sudo k3d cluster delete dev-cluster || true
sleep 2

# remove kubectl
echo "Removing kubectl..."
sudo rm -f /usr/local/bin/kubectl

# remove argocd cli
echo "Removing argocd cli..."
sudo rm -f /usr/local/bin/argocd

# remove k3d
echo "Removing k3d..."
sudo rm -f /usr/local/bin/k3d

# remove kubeconfig
echo "Removing kubeconfig..."
rm -f ~/.kube/config