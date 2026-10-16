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

  if [[ "$backend_status" == "healthy" &&
        "$frontend_status" == "healthy" ]]; then
    echo "Backend and frontend are healthy."
    exit 0
  fi

  echo "Attempt $attempt/$MAX_ATTEMPTS: backend=$backend_status frontend=$frontend_status"
  sleep "$SLEEP_SECONDS"
done

echo "ERROR: Application health check failed." >&2
docker compose -f docker-compose.prod.yml ps || true
docker logs --tail 100 todo-backend || true
docker logs --tail 100 todo-frontend || true
exit 1
