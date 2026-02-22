#!/bin/bash

apt update -y
apt install curl -y

# install k3s server
curl -sfL https://get.k3s.io |  INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

echo "Waiting for k3s..."
sleep 25

# fix kubectl permissions
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# deploy apps automatically
kubectl apply -f /vagrant/confs
