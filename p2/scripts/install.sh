#!/bin/bash

set -e

apt update -y
apt install -y curl

# Install k3s server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --node-ip=192.168.56.110" sh -

echo "Waiting for k3s service..."
systemctl enable k3s
systemctl start k3s

# Wait until API server is ready
echo "Waiting for Kubernetes API..."
until kubectl get nodes >/dev/null 2>&1; do
  echo "K3s not ready yet..."
  sleep 5
done

echo "K3s is ready."

# Configure kubeconfig for vagrant user
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Deploy apps
kubectl apply -f /vagrant/confs

echo "Deployment finished."