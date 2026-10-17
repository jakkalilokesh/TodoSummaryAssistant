#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run through SSM with root privileges." >&2
  exit 1
fi

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl jq awscli docker.io docker-compose-v2
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y ca-certificates curl-minimal jq awscli docker
elif command -v yum >/dev/null 2>&1; then
  yum install -y ca-certificates curl-minimal jq awscli docker
else
  echo "ERROR: No supported package manager found (apt-get, dnf, or yum)." >&2
  exit 1
fi

systemctl enable --now docker

if ! docker compose version >/dev/null 2>&1; then
  arch="$(uname -m)"
  case "$arch" in
    x86_64) compose_arch=x86_64 ;;
    aarch64|arm64) compose_arch=aarch64 ;;
    *)
      echo "ERROR: Unsupported CPU architecture: $arch" >&2
      exit 1
      ;;
  esac

  install -d -m 0755 /usr/local/lib/docker/cli-plugins
  curl -fsSL "https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-${compose_arch}" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod 0755 /usr/local/lib/docker/cli-plugins/docker-compose
fi

install -d -o root -g root -m 0750 /opt/todo-assistant
install -d -o root -g root -m 0750 /opt/todo-assistant/releases

echo "Application server setup completed."
docker --version
docker compose version
aws --version