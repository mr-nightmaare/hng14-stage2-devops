#!/usr/bin/env bash
set -euo pipefail

# ── Rolling Deploy Script ──
# Performs a rolling update for each service:
#   1. Start a new container with health check
#   2. Wait up to 60s for it to become healthy
#   3. If healthy → stop the old container
#   4. If not healthy → abort and leave the old container running

COMPOSE_PROJECT="hng14-stage2-devops"
TIMEOUT=60

deploy_service() {
  local service="$1"
  echo ""
  echo "=== Rolling deploy: $service ==="

  # Build the new image
  echo "Building new image for $service..."
  docker compose build "$service"

  # Scale up: start a new container alongside the old one
  local old_container
  old_container=$(docker compose ps -q "$service" 2>/dev/null || true)

  if [ -z "$old_container" ]; then
    echo "No existing container for $service, starting fresh..."
    docker compose up -d "$service"
    echo "Started $service"
    return 0
  fi

  # Start the new container
  echo "Starting new $service container..."
  docker compose up -d --no-deps --scale "$service=2" "$service" 2>/dev/null || \
    docker compose up -d --no-deps "$service"

  # Wait for the new container to pass health check
  echo "Waiting up to ${TIMEOUT}s for new container to become healthy..."
  local elapsed=0
  local healthy=false

  while [ "$elapsed" -lt "$TIMEOUT" ]; do
    # Check if service is healthy
    local health_status
    health_status=$(docker compose ps "$service" --format json 2>/dev/null | \
      tail -1 | python3 -c "import sys,json; print(json.load(sys.stdin).get('Health',''))" 2>/dev/null || echo "")

    if [ "$health_status" = "healthy" ]; then
      healthy=true
      break
    fi

    sleep 5
    elapsed=$((elapsed + 5))
    echo "  ${elapsed}s / ${TIMEOUT}s — status: ${health_status:-starting}"
  done

  if [ "$healthy" = true ]; then
    echo "New $service container is healthy!"

    # Stop the old container if it's different
    if [ -n "$old_container" ]; then
      echo "Stopping old container: ${old_container:0:12}..."
      docker stop "$old_container" 2>/dev/null || true
      docker rm "$old_container" 2>/dev/null || true
    fi

    # Scale back to 1
    docker compose up -d --no-deps --scale "$service=1" "$service" 2>/dev/null || true

    echo "=== $service deployed successfully ==="
  else
    echo "ERROR: New $service container did not become healthy within ${TIMEOUT}s"
    echo "Aborting deploy — old container is still running"

    # Remove the unhealthy new container, keep the old one
    docker compose up -d --no-deps --scale "$service=1" "$service" 2>/dev/null || true
    return 1
  fi
}

echo "=============================="
echo "  Rolling Deployment Started"
echo "=============================="

# Deploy services in dependency order
deploy_service "api"
deploy_service "worker"
deploy_service "frontend"

echo ""
echo "=============================="
echo "  All services deployed!"
echo "=============================="
docker compose ps
