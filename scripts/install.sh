#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> GoToSocial – instalace"

# Kontrola závislostí
for cmd in docker docker-compose; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "CHYBA: '$cmd' není nainstalován." >&2
    exit 1
  fi
done

# Kontrola .env souboru
if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "CHYBA: Soubor .env neexistuje. Zkopírujte .env.example a vyplňte hodnoty."
  echo "  cp .env.example .env && nano .env"
  exit 1
fi

# Vytvoření datového adresáře
mkdir -p "$ROOT_DIR/data"

echo "==> Spouštění kontejneru..."
cd "$ROOT_DIR"
docker-compose pull
docker-compose up -d

echo ""
echo "GoToSocial je spuštěn na http://127.0.0.1:8080"
echo ""
echo "Dalsi kroky:"
echo "  1. Nakonfigurujte Nginx: sudo cp nginx/gotosocial.conf /etc/nginx/sites-available/gotosocial"
echo "  2. Ziskejte SSL certifikat: sudo certbot --nginx -d vase-domena.cz"
echo "  3. Vytvořte admin účet:"
echo "     docker-compose exec gotosocial /gotosocial/gotosocial admin account create \\"
echo "       --username admin --email admin@vase-domena.cz --password 'silne_heslo'"
echo "     docker-compose exec gotosocial /gotosocial/gotosocial admin account promote \\"
echo "       --username admin"
