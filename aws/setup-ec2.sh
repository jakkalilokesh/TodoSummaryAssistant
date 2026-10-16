#!/bin/bash
set -e

echo "Updating system packages..."
dnf update -y

echo "Installing Docker and AWS CLI..."
dnf install -y docker awscli curl

echo "Starting Docker..."
systemctl enable --now docker

echo "Creating application directory..."
mkdir -p /opt/todo-assistant
chmod 755 /opt/todo-assistant

echo "Checking installed tools..."
docker --version
aws --version

echo "EC2 setup completed successfully."
