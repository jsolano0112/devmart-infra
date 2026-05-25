#!/bin/bash
if grep -q $'\r' "$0" 2>/dev/null; then
  sed -i 's/\r$//' "$0"
  exec "$0" "$@"
fi

set -eu

INFRA_BRANCH="${1:?Usage: remote-deploy.sh <git-branch>}"
REPO_DIR="/home/ubuntu/devmart-infra"
REPO_URL="https://github.com/jsolano0112/devmart-infra.git"

for attempt in $(seq 1 30); do
  if command -v docker-compose >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "docker-compose no esta instalado" >&2
  exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  git clone -b "$INFRA_BRANCH" "$REPO_URL" "$REPO_DIR"
else
  cd "$REPO_DIR"
  git fetch origin
  git checkout "$INFRA_BRANCH"
  git pull --ff-only origin "$INFRA_BRANCH" || git pull origin "$INFRA_BRANCH"
fi

if [ -f /tmp/stack.env ]; then
  install -m 600 -o ubuntu -g ubuntu /tmp/stack.env "$REPO_DIR/.env"
  rm -f /tmp/stack.env
fi

for file in docker-compose.yml nginx.conf; do
  if [ -f "/tmp/${file}" ]; then
    install -m 644 -o ubuntu -g ubuntu "/tmp/${file}" "$REPO_DIR/${file}"
    rm -f "/tmp/${file}"
  fi
done

cd "$REPO_DIR"
docker-compose pull
docker-compose up -d
docker-compose ps
