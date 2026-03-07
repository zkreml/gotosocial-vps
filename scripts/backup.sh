#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$ROOT_DIR/backups"
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="$BACKUP_DIR/gotosocial-backup-$DATE.tar.gz"

echo "==> GoToSocial – záloha"

mkdir -p "$BACKUP_DIR"

echo "==> Zastavuji kontejner pro konzistentní zálohu..."
cd "$ROOT_DIR"
docker-compose stop gotosocial

echo "==> Vytvářím zálohu: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" \
  --exclude='./backups' \
  -C "$ROOT_DIR" \
  data/ config/ .env 2>/dev/null || true

echo "==> Spouštím kontejner..."
docker-compose start gotosocial

echo "==> Záloha uložena: $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"

# Smazání záloh starších než 30 dní
find "$BACKUP_DIR" -name "gotosocial-backup-*.tar.gz" -mtime +30 -delete
echo "==> Staré zálohy (>30 dní) odstraněny."
