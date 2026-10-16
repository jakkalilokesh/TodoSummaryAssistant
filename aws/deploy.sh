
#!/bin/bash
set -Eeuo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

APP_DIR="/opt/todo-assistant"
COMPOSE_FILE="$APP_DIR/docker-compose.prod.yml"
ENV_FILE="$APP_DIR/app.env"

export BACKEND_IMAGE="$ECR_REGISTRY/todo-assistant-backend:$IMAGE_TAG"
export FRONTEND_IMAGE="$ECR_REGISTRY/todo-assistant-frontend:$IMAGE_TAG"

echo "Deploying version: $IMAGE_TAG"

# Check deployment files
test -f "$COMPOSE_FILE" || {
  echo "Production Compose file is missing."
  exit 1
}

test -f "$ENV_FILE" || {
  echo "Application environment file is missing."
  exit 1
}

# Log in to ECR
aws ecr get-login-password --region "$AWS_REGION" |
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Validate configuration before changing containers
docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" config -q

# Pull the selected images
docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" pull

# Start the application
docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" up -d

# Verify the frontend
for attempt in $(seq 1 12); do
  if curl --fail --silent http://localhost/ >/dev/null; then
    echo "Frontend health check passed."
    exit 0
  fi

  echo "Waiting for frontend ($attempt/12)..."
  sleep 5
done

echo "Health check failed. Recent container logs:"
docker compose \
  --env-file "$ENV_FILE" \
  -f "$COMPOSE_FILE" logs --tail=100

exit 1
