#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_NAME="${STACK_NAME:-ecommerce}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
REGISTRY="${REGISTRY:-192.168.102.114:5000}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

if ! command -v docker >/dev/null 2>&1; then
  error "Docker est requis pour deployer la stack."
  exit 1
fi

cd "${ROOT_DIR}"

info "Build des images..."
docker build -t "${REGISTRY}/frontend:latest" --target production ./frontend
docker build -t "${REGISTRY}/auth-service:latest" ./services/auth-service
docker build -t "${REGISTRY}/product-service:latest" ./services/product-service
docker build -t "${REGISTRY}/order-service:latest" ./services/order-service

info "Push vers le registre local (${REGISTRY})..."
docker push "${REGISTRY}/frontend:latest"
docker push "${REGISTRY}/auth-service:latest"
docker push "${REGISTRY}/product-service:latest"
docker push "${REGISTRY}/order-service:latest"

info "Deploiement Docker Swarm de ${STACK_NAME} avec ${COMPOSE_FILE}"
docker stack deploy -c "${COMPOSE_FILE}" "${STACK_NAME}"
docker stack services "${STACK_NAME}" || true
