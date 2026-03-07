#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> GoToSocial – aktualizace"

cd "$ROOT_DIR"

echo "==> Stahuji nejnovější obraz..."
docker-compose pull

echo "==> Restartuji kontejner..."
docker-compose up -d --force-recreate

echo "==> Aktualizace dokončena."
docker-compose ps
