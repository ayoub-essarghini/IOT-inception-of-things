#!/bin/bash

sudo apt update -y
sudo apt install curl -y

curl -sfL https://get.k3s.io | sh -

echo "Waiting k3s server..."
sleep 25

sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/token
