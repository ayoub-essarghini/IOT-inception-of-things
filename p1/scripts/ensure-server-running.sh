#!/bin/bash
set -euo pipefail

server_id_file=".vagrant/machines/aes-sargS/virtualbox/id"

server_ready() {
  [ -s token ] && timeout 2 bash -c '</dev/tcp/192.168.56.110/6443' 2>/dev/null
}

wait_for_server() {
  for _ in {1..90}; do
    if server_ready; then
      return 0
    fi

    sleep 2
  done

  return 1
}

if [ -f "$server_id_file" ]; then
  server_id="$(cat "$server_id_file")"
  server_state="$(VBoxManage showvminfo "$server_id" --machinereadable | sed -n 's/^VMState="\(.*\)"$/\1/p')"

  if [ "$server_state" = "paused" ]; then
    VBoxManage controlvm "$server_id" resume
  elif [ "$server_state" != "running" ]; then
    vagrant up aes-sargS
  fi
else
  vagrant up aes-sargS
fi

if wait_for_server; then
  exit 0
fi

vagrant provision aes-sargS
wait_for_server
