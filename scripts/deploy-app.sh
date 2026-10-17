#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

APP_DIR="${APP_DIR:-/opt/todo-assistant}"

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${BACKEND_IMAGE:?BACKEND_IMAGE is required}"
: "${FRONTEND_IMAGE:?FRONTEND_IMAGE is required}"
: "${SECRET_ARN:?SECRET_ARN is required}"

export AWS_DEFAULT_REGION="$AWS_REGION"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: Run this script through SSM with root privileges." >&2
  exit 1
fi

for tool in aws docker jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $tool" >&2
    exit 1
  fi
done

install -d -o root -g root -m 0750 "$APP_DIR"
cd "$APP_DIR"

# Retrieve database credentials from Secrets Manager.
echo "Retrieving application configuration from Secrets Manager..."

secret_json="$(aws secretsmanager get-secret-value \
  --region "$AWS_REGION" \
  --secret-id "$SECRET_ARN" \
  --query SecretString \
  --output text)"

if [[ -z "$secret_json" || "$secret_json" == "None" ]]; then
  echo "ERROR: Secrets Manager returned an empty secret." >&2
  exit 1
fi

# Validate required keys without printing their values.
if ! printf '%s' "$secret_json" | jq -e '
  (.DB_URL | strings | length > 0) and
  (.DB_USERNAME | strings | length > 0) and
  (.DB_PASSWORD | strings | length > 0)
' >/dev/null; then
  unset secret_json
  echo "ERROR: Secret must contain DB_URL, DB_USERNAME, and DB_PASSWORD." >&2
  exit 1
fi

# Write dotenv values as quoted JSON strings, which Compose can parse.
tmp_env="$(mktemp "$APP_DIR/.app.env.XXXXXX")"
trap 'rm -f "${tmp_env:-}"' EXIT

printf '%s' "$secret_json" | jq -er '
  "DB_URL=" + (.DB_URL | tojson) + "\n" +
  "DB_USERNAME=" + (.DB_USERNAME | tojson) + "\n" +
  "DB_PASSWORD=" + (.DB_PASSWORD | tojson) + "\n"
' > "$tmp_env"

unset secret_json

chown root:root "$tmp_env"
chmod 0600 "$tmp_env"
mv -f "$tmp_env" "$APP_DIR/app.env"
unset tmp_env
trap - EXIT

# Preserve the previous known-good release for rollback.
if [[ -f "$APP_DIR/last-good.env" ]]; then
  cp "$APP_DIR/last-good.env" "$APP_DIR/previous-release.env"
  chown root:root "$APP_DIR/previous-release.env"
  chmod 0600 "$APP_DIR/previous-release.env"
fi

# Authenticate to ECR using the EC2 instance IAM role.
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

export BACKEND_IMAGE FRONTEND_IMAGE

echo "Pulling application images..."
docker pull "$BACKEND_IMAGE"
docker pull "$FRONTEND_IMAGE"

# Deploy the new release.
if ! docker compose \
  --env-file "$APP_DIR/app.env" \
  -f "$APP_DIR/docker-compose.prod.yml" \
  up -d --remove-orphans; then

  echo "ERROR: Compose deployment failed." >&2

  if [[ -f "$APP_DIR/previous-release.env" ]]; then
    cp "$APP_DIR/previous-release.env" "$APP_DIR/last-good.env"
    bash "$APP_DIR/rollback.sh" || true
  fi

  exit 1
fi

# Roll back if health checks fail.
if ! bash "$APP_DIR/health-check.sh"; then
  echo "ERROR: New release failed health checks." >&2

  if [[ -f "$APP_DIR/previous-release.env" ]]; then
    cp "$APP_DIR/previous-release.env" "$APP_DIR/last-good.env"
    bash "$APP_DIR/rollback.sh" || true
  fi

  exit 1
fi

# Record the release only after health checks succeed.
printf 'BACKEND_IMAGE=%q\nFRONTEND_IMAGE=%q\n' \
  "$BACKEND_IMAGE" "$FRONTEND_IMAGE" > "$APP_DIR/last-good.env"

chown root:root "$APP_DIR/last-good.env"
chmod 0600 "$APP_DIR/last-good.env"

rm -f "$APP_DIR/previous-release.env"

echo "Deployment completed successfully."
