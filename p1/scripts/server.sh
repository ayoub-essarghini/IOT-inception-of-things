#!/bin/bash
set -euo pipefail

command -v curl >/dev/null 2>&1 || {
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl
}

sudo rm -f /vagrant/token

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="v1.30.2+k3s1" \
  INSTALL_K3S_EXEC="server --node-ip 192.168.56.110 --advertise-address 192.168.56.110 --tls-san 192.168.56.110 --flannel-iface enp0s8 --write-kubeconfig-mode 644 --disable traefik --disable servicelb --disable metrics-server" \
  sh -

echo "Waiting for k3s server..."
until sudo k3s kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/token
sudo chown vagrant:vagrant /vagrant/token
