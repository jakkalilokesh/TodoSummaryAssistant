#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "ERROR: This script supports Ubuntu/Debian agents only." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=()
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required to install packages." >&2
    exit 1
  fi
  SUDO=(sudo)
fi

echo "Updating package indexes..."
"${SUDO[@]}" apt-get update

echo "Installing base tools..."
"${SUDO[@]}" apt-get install -y \
  ca-certificates \
  curl \
  git \
  jq \
  unzip \
  openjdk-17-jdk \
  maven \
  nodejs \
  npm \
  docker.io \
  awscli

required_tools=(git java mvn node npm docker aws jq)

for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required tool is missing: $tool" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is installed but the Jenkins agent cannot access it." >&2
  echo "Configure Docker permissions for the agent account, then restart the agent." >&2
  exit 1
fi

echo "Verified tool versions:"
java -version
mvn -version
node --version
npm --version
docker --version
aws --version

echo "Base tool verification completed."
