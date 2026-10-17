#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/todo-assistant}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

cd "$APP_DIR"

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  backend_status="$(
    docker inspect --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      todo-backend 2>/dev/null || true
  )"

  frontend_status="$(
    docker inspect --format \
      '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
      todo-frontend 2>/dev/null || true
  )"

  backend_ok=false
  frontend_ok=false

  if [[ "$backend_status" == "healthy" || "$backend_status" == "running" ]]; then
    backend_ok=true
  fi

  if [[ "$frontend_status" == "healthy" || "$frontend_status" == "running" ]]; then
    frontend_ok=true
  fi

  if [[ "$backend_ok" == true && "$frontend_ok" == true ]]; then
    echo "Backend and frontend containers are running and healthy, or have no configured health check."
    exit 0
  fi

  echo "Attempt $attempt/$MAX_ATTEMPTS: backend=$backend_status frontend=$frontend_status"

  if (( attempt < MAX_ATTEMPTS )); then
    sleep "$SLEEP_SECONDS"
  fi
done

echo "ERROR: Application health check failed." >&2
docker compose -f docker-compose.prod.yml ps || true
docker logs --tail 100 todo-backend || true
docker logs --tail 100 todo-frontend || true