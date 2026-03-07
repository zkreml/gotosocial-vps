#!/usr/bin/env bash
export TERM=xterm-256color
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> GoToSocial – interaktivní instalace"
echo ""

# === Interaktivní vstup ===
read -rp "Doména serveru (např. social.example.cz): " GTS_DOMAIN
read -rp "Account-domain (např. example.cz; Enter = shodná s doménou serveru): " GTS_ACCOUNT_DOMAIN

if [ -z "$GTS_DOMAIN" ]; then
  echo "CHYBA: Doména je povinná." >&2
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

# === Konfigurace nginx HTTP ===

NGINX_CONF="$ROOT_DIR/nginx/gotosocial.conf"
NGINX_CONF_ZKREML="$ROOT_DIR/nginx/zkreml.cz.conf"

echo ""
echo "==> Nastavení nginx konfigurace..."

# Záloha originálů pro idempotentní opakované spuštění
[ -f "${NGINX_CONF}.orig" ]        || cp "$NGINX_CONF"        "${NGINX_CONF}.orig"
[ -f "${NGINX_CONF_ZKREML}.orig" ] || cp "$NGINX_CONF_ZKREML" "${NGINX_CONF_ZKREML}.orig"

# Vždy pracuj z originálu
cp "${NGINX_CONF}.orig"        "$NGINX_CONF"
cp "${NGINX_CONF_ZKREML}.orig" "$NGINX_CONF_ZKREML"

# nginx gotosocial.conf – dosaď GTS_HOST
sed -i "s|GTS_HOST|${GTS_DOMAIN}|g" "$NGINX_CONF"

# nginx zkreml.cz.conf – dosaď ACCOUNT_DOMAIN a GTS_HOST
if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  sed -i "s|ACCOUNT_DOMAIN|${GTS_ACCOUNT_DOMAIN}|g" "$NGINX_CONF_ZKREML"
  sed -i "s|GTS_HOST|${GTS_DOMAIN}|g"               "$NGINX_CONF_ZKREML"
fi

# === Nasazení nginx HTTP konfigurace ===
echo "==> Nasazení nginx HTTP konfigurace..."
cp "$NGINX_CONF" /etc/nginx/sites-available/gotosocial
ln -sf /etc/nginx/sites-available/gotosocial /etc/nginx/sites-enabled/gotosocial

if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  cp "$NGINX_CONF_ZKREML" "/etc/nginx/sites-available/${GTS_ACCOUNT_DOMAIN}"
  ln -sf "/etc/nginx/sites-available/${GTS_ACCOUNT_DOMAIN}" \
         "/etc/nginx/sites-enabled/${GTS_ACCOUNT_DOMAIN}"
fi

nginx -t
systemctl reload nginx

# === SSL certifikáty ===
echo ""
echo "==> Získání SSL certifikátu pro ${GTS_DOMAIN}..."
certbot --nginx -d "$GTS_DOMAIN"

if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  echo "==> Získání SSL certifikátu pro ${GTS_ACCOUNT_DOMAIN}..."
  certbot --nginx -d "$GTS_ACCOUNT_DOMAIN"
fi

# === Konfigurace docker-compose.yml ===
echo "==> Konfigurace docker-compose.yml..."
DC_FILE="$ROOT_DIR/docker-compose.yml"
[ -f "${DC_FILE}.orig" ] || cp "$DC_FILE" "${DC_FILE}.orig"
cp "${DC_FILE}.orig" "$DC_FILE"

sed -i "s|GTS_HOST_PLACEHOLDER|${GTS_DOMAIN}|g" "$DC_FILE"

if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  sed -i "s|ACCOUNT_DOMAIN_PLACEHOLDER|${GTS_ACCOUNT_DOMAIN}|g" "$DC_FILE"
else
  sed -i "s|ACCOUNT_DOMAIN_PLACEHOLDER|${GTS_DOMAIN}|g" "$DC_FILE"
fi

# === Spuštění kontejneru ===
mkdir -p "$ROOT_DIR/data"
echo "==> Spouštění kontejneru..."
cd "$ROOT_DIR"
$DC pull
$DC up -d

echo "==> Čekání na start GoToSocial (15 s)..."
sleep 15

echo "==> Stav kontejneru:"
$DC ps

# === Hotovo ===
echo ""
echo "==> Instalace dokončena!"
echo ""
echo "    GoToSocial:  https://${GTS_DOMAIN}"
if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  echo "    Hlavní doména: https://${GTS_ACCOUNT_DOMAIN}"
  echo "    Účty budou mít formát @uživatel@${GTS_ACCOUNT_DOMAIN}"
fi
echo ""
echo "Pro vytvoření admin účtu spusťte:"
echo "    cd ${ROOT_DIR}"
echo "    $DC exec gotosocial /gotosocial/gotosocial admin account create \\"
echo "        --username <uživatel> --email <email> --password <heslo>"
echo "    $DC exec gotosocial /gotosocial/gotosocial admin account promote \\"
echo "        --username <uživatel>"
echo ""
echo "NEZAPOMENOUT nastavit DNS záznamy:"
echo "    ${GTS_DOMAIN}  -> IP tohoto serveru"
if [ "$SEPARATE_ACCOUNT_DOMAIN" = true ]; then
  echo "    ${GTS_ACCOUNT_DOMAIN} -> IP tohoto serveru"
fi
