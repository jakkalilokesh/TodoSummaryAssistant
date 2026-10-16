#!/bin/bash
set -Eeuo pipefail

trap 'echo "ERROR: EC2 setup failed at line ${LINENO}" >&2' ERR

echo "Updating system packages..."
dnf update -y

echo "Installing Docker, AWS CLI, and utilities..."
dnf install -y docker awscli curl jq

echo "Starting Docker..."
systemctl enable --now docker

echo "Checking Docker Compose..."
if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is missing."
    echo "Install a compatible Docker Compose v2 plugin before deployment."
    exit 1
fi

echo "Checking Systems Manager Agent..."
if systemctl list-unit-files amazon-ssm-agent.service \
    --no-legend | grep -q amazon-ssm-agent; then
    systemctl enable --now amazon-ssm-agent
else
    echo "WARNING: SSM Agent is not installed."
    echo "SSM-based deployment will not work until it is installed and running."
fi

echo "Creating application directories..."
install -d -m 755 /opt/todo-assistant
install -d -m 755 /opt/todo-assistant/releases

echo "Verifying installations..."
docker --version
aws --version

echo "EC2 setup completed successfully."