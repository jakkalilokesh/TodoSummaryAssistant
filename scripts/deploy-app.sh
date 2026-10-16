#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

APP_DIR="${APP_DIR:-/opt/todo-assistant}"

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${BACKEND_IMAGE:?BACKEND_IMAGE is required}"
: "${FRONTEND_IMAGE:?FRONTEND_IMAGE is required}"
: "${SECRET_ARN:?SECRET_ARN is required}"
: "${CORS_ALLOWED_ORIGINS:?CORS_ALLOWED_ORIGINS is required}"

export AWS_DEFAULT_REGION="$AWS_REGION"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run this script through SSM with root privileges." >&2
  exit 1
fi

install -d -o root -g root -m 0750 "$APP_DIR"
cd "$APP_DIR"

# Retrieve application secrets without printing them.
secret_json="$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString \
  --output text)"

export DB_URL DB_USERNAME DB_PASSWORD
export COHERE_API_KEY SLACK_WEBHOOK_URL

DB_URL="$(jq -er '.DB_URL' <<< "$secret_json")"
DB_USERNAME="$(jq -er '.DB_USERNAME' <<< "$secret_json")"
DB_PASSWORD="$(jq -er '.DB_PASSWORD' <<< "$secret_json")"
COHERE_API_KEY="$(jq -r '.COHERE_API_KEY // ""' <<< "$secret_json")"
SLACK_WEBHOOK_URL="$(jq -r '.SLACK_WEBHOOK_URL // ""' <<< "$secret_json")"
unset secret_json

# Save the previous images only after they have passed a health check.
if [[ -f "$APP_DIR/last-good.env" ]]; then
  cp "$APP_DIR/last-good.env" "$APP_DIR/previous-release.env"
  chmod 0600 "$APP_DIR/previous-release.env"
fi

# Authenticate with ECR using the EC2 IAM role.
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

export BACKEND_IMAGE FRONTEND_IMAGE

docker pull "$BACKEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

if ! docker compose -f docker-compose.prod.yml up -d --remove-orphans; then
  echo "ERROR: Compose deployment failed." >&2
  if [[ -f "$APP_DIR/previous-release.env" ]]; then
    cp "$APP_DIR/previous-release.env" "$APP_DIR/last-good.env"
    bash "$APP_DIR/rollback.sh" || true
  fi
  exit 1
fi

if ! bash "$APP_DIR/health-check.sh"; then
  echo "ERROR: New release did not become healthy." >&2
  if [[ -f "$APP_DIR/previous-release.env" ]]; then
    cp "$APP_DIR/previous-release.env" "$APP_DIR/last-good.env"
    bash "$APP_DIR/rollback.sh" || true
  fi
  exit 1
fi

# Record the new release only after successful health checks.
printf 'BACKEND_IMAGE=%q\nFRONTEND_IMAGE=%q\n' \
  "$BACKEND_IMAGE" "$FRONTEND_IMAGE" > "$APP_DIR/last-good.env"

chmod 0600 "$APP_DIR/last-good.env"
rm -f "$APP_DIR/previous-release.env"

echo "Deployment completed successfully."
