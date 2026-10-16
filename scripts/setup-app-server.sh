#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run through SSM with root privileges." >&2
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "ERROR: This script supports Ubuntu/Debian only." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl jq awscli docker.io docker-compose-v2

systemctl enable --now docker

install -d -o root -g root -m 0750 /opt/todo-assistant
install -d -o root -g root -m 0750 /opt/todo-assistant/releases

echo "Application server setup completed."
docker --version
docker compose version
aws --version