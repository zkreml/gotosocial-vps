#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> GoToSocial – interaktivní instalace"
echo ""

# === Interaktivní vstup ===
read -rp "Doména serveru (např. social.example.cz): " GTS_DOMAIN
read -rp "Account-domain (např. example.cz; Enter = shodná s doménou serveru): " GTS_ACCOUNT_DOMAIN
read -rp "Admin uživatelské jméno: " ADMIN_USER
read -rp "Admin e-mail: " ADMIN_EMAIL
while true; do
  read -rsp "Admin heslo: " ADMIN_PASS
  echo ""
  read -rsp "Admin heslo (znovu): " ADMIN_PASS2
  echo ""
  [ "$ADMIN_PASS" = "$ADMIN_PASS2" ] && break
  echo "Hesla se neshodují, zkuste znovu."
done

if [ -z "$GTS_DOMAIN" ] || [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASS" ]; then
  echo "CHYBA: Doména, admin uživatel, e-mail a heslo jsou povinné." >&2
  exit 1
fi

SEPARATE_ACCOUNT_DOMAIN=false
if [ -n "$GTS_ACCOUNT_DOMAIN" ] && [ "$GTS_ACCOUNT_DOMAIN" != "$GTS_DOMAIN" ]; then
  SEPARATE_ACCOUNT_DOMAIN=true
fi

# === Instalace závislostí ===

_install_docker() {
  echo "==> Instalace Dockeru..."
  apt-get update -q
  apt-get install -y ca-certificates curl gnupg lsb-release
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
}

_install_nginx() {
  echo "==> Instalace Nginx..."
  apt-get update -q
  apt-get install -y nginx
  systemctl enable --now nginx
}

_install_certbot() {
  echo "==> Instalace Certbot..."
  apt-get install -y certbot python3-certbot-nginx
}

if ! command -v docker &>/dev/null; then
  _install_docker
fi

# Detekce příkazu docker compose (plugin) nebo docker-compose (standalone)
if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose &>/dev/null; then
  DC="docker-compose"
else
  echo "==> Instalace docker-compose-plugin..."
  apt-get install -y docker-compose-plugin
  DC="docker compose"
fi

if ! command -v nginx &>/dev/null; then
  _install_nginx
fi

if ! command -v certbot &>/dev/null; then
  _install_certbot
fi

# === Konfigurace souborů ===

CONFIG_FILE="$ROOT_DIR/config/config.yaml"
NGINX_CONF="$ROOT_DIR/nginx/gotosocial.conf"

echo ""
echo "==> Nastavení konfigurace..."

# Záloha originálů pro idempotentní opakované spuštění
[ -f "${CONFIG_FILE}.orig" ] || cp "$CONFIG_FILE" "${CONFIG_FILE}.orig"
[ -f "${NGINX_CONF}.orig"  ] || cp "$NGINX_CONF"  "${NGINX_CONF}.orig"

# Vždy pracuj z originálu
cp "${CONFIG_FILE}.orig" "$CONFIG_FILE"
cp "${NGINX_CONF}.orig"  "$NGINX_CONF"

# config.yaml – host
sed -i "s|host: \".*\"|host: \"${GTS_DOMAIN}\"|" "$CONFIG_FILE"

# config.yaml – account-domain (odkomentuj pouze při odlišné doméně)
if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  sed -i "s|# account-domain: \".*\"|account-domain: \"${GTS_ACCOUNT_DOMAIN}\"|" "$CONFIG_FILE"
fi

# nginx – server_name a references na doménu
sed -i "s|server_name .*;|server_name ${GTS_DOMAIN};|g" "$NGINX_CONF"
sed -i "s|vase-domena\.cz|${GTS_DOMAIN}|g" "$NGINX_CONF"

# Nasazení nginx konfigurace
echo "==> Nasazení Nginx konfigurace..."
cp "$NGINX_CONF" /etc/nginx/sites-available/gotosocial
ln -sf /etc/nginx/sites-available/gotosocial /etc/nginx/sites-enabled/gotosocial
nginx -t
systemctl reload nginx

# .env – vytvoř z example pokud neexistuje
if [ ! -f "$ROOT_DIR/.env" ]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
fi

# === Spuštění kontejneru ===
mkdir -p "$ROOT_DIR/data"
echo "==> Spouštění kontejneru..."
cd "$ROOT_DIR"
$DC pull
$DC up -d

echo "==> Čekání na start GoToSocial (10 s)..."
sleep 10

# === Vytvoření admin účtu ===
echo "==> Vytváření admin účtu..."
$DC exec gotosocial /gotosocial/gotosocial admin account create \
  --username "$ADMIN_USER" \
  --email    "$ADMIN_EMAIL" \
  --password "$ADMIN_PASS"

$DC exec gotosocial /gotosocial/gotosocial admin account promote \
  --username "$ADMIN_USER"

# === SSL certifikát ===
echo ""
echo "==> Získání SSL certifikátu přes Certbot..."
certbot --nginx -d "$GTS_DOMAIN"

echo ""
echo "==> Instalace dokončena!"
echo "    GoToSocial je dostupný na https://${GTS_DOMAIN}"
if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  echo "    Účty budou mít formát @uživatel@${GTS_ACCOUNT_DOMAIN}"
fi
