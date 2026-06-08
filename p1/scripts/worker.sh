#!/bin/bash
set -euo pipefail

echo "Waiting for token..."

while [ ! -s /vagrant/token ]; do
  sleep 2
done

TOKEN=$(cat /vagrant/token)

echo "Waiting for k3s server API..."
while ! timeout 2 bash -c '</dev/tcp/192.168.56.110/6443' 2>/dev/null; do
  echo "k3s server API is not reachable yet at 192.168.56.110:6443"
  sleep 5
done

if systemctl list-unit-files k3s-agent.service >/dev/null 2>&1; then
  sudo systemctl reset-failed k3s-agent || true
fi

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="v1.30.2+k3s1" \
  INSTALL_K3S_SKIP_START=true \
  K3S_URL=https://192.168.56.110:6443 \
  K3S_TOKEN="$TOKEN" \
  INSTALL_K3S_EXEC="agent --node-ip 192.168.56.111 --flannel-iface enp0s8" \
  sh -

sudo systemctl start --no-block k3s-agent

echo "Waiting for k3s agent..."
for attempt in {1..30}; do
  if timeout 2 bash -c '</dev/tcp/192.168.56.110/6443' 2>/dev/null; then
    sudo systemctl reset-failed k3s-agent || true
    sudo systemctl start --no-block k3s-agent || true
  fi

  if sudo systemctl is-active --quiet k3s-agent; then
    exit 0
  fi

  if sudo systemctl is-failed --quiet k3s-agent; then
    sudo journalctl -u k3s-agent --no-pager -n 80
    sudo systemctl reset-failed k3s-agent
    sudo systemctl start --no-block k3s-agent || true
  fi

  active_state="$(systemctl show -p ActiveState --value k3s-agent || true)"
  main_pid="$(systemctl show -p MainPID --value k3s-agent || true)"

  if [ "$active_state" = "activating" ] && [ "${main_pid:-0}" != "0" ] && [ "$attempt" -ge 6 ]; then
    echo "k3s-agent is still activating, but the service process is running."
    exit 0
  fi

  sleep 2
done

sudo journalctl -u k3s-agent --no-pager -n 80
echo "k3s-agent is still starting in the background." >&2
