#!/usr/bin/env bash
# bootstrap.sh – první nastavení čistého VPS
# Spusťte jako root: bash bootstrap.sh
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "CHYBA: Spusťte jako root (sudo bash bootstrap.sh)." >&2
  exit 1
fi

TARGET_USER="archos"

echo "==> Bootstrap VPS pro GoToSocial"
echo "    Bude vytvořen uživatel: ${TARGET_USER}"
echo ""

SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0de1Ry3HwDjTYbgTlgM+iF4F5CbBwqYMTXnTGLP0ff archos@arch-linux"

# === Aktualizace systému ===
echo "==> Aktualizace systému..."
apt-get update -q
apt-get upgrade -y

# === Instalace základních balíků ===
apt-get install -y ufw curl git

# === Vytvoření uživatele ===
if id "$TARGET_USER" &>/dev/null; then
  echo "==> Uživatel ${TARGET_USER} již existuje, přeskakuji."
else
  echo "==> Vytváření uživatele ${TARGET_USER}..."
  useradd -m -s /bin/bash "$TARGET_USER"
  # Přidání do skupiny sudo
  usermod -aG sudo "$TARGET_USER"
  # Zamknutí hesla – přihlášení pouze přes SSH klíč
  passwd -l "$TARGET_USER"
  echo "    Uživatel vytvořen."
fi

# === SSH klíč ===
echo "==> Nastavení SSH klíče..."
SSH_DIR="/home/${TARGET_USER}/.ssh"
mkdir -p "$SSH_DIR"

# Přidej klíč jen pokud tam ještě není
if ! grep -qF "$SSH_PUBKEY" "${SSH_DIR}/authorized_keys" 2>/dev/null; then
  echo "$SSH_PUBKEY" >> "${SSH_DIR}/authorized_keys"
  echo "    Klíč přidán."
else
  echo "    Klíč již existuje, přeskakuji."
fi

chmod 700 "$SSH_DIR"
chmod 600 "${SSH_DIR}/authorized_keys"
chown -R "${TARGET_USER}:${TARGET_USER}" "$SSH_DIR"

# === Zpevnění SSH démon konfigurace ===
echo "==> Zpevnění SSH konfigurace..."
SSHD_CONF="/etc/ssh/sshd_config"
# Zakaz přihlášení roota heslem
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONF"
# Zakaz PasswordAuthentication (pouze klíče)
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONF"
systemctl reload ssh.service

# === UFW firewall ===
echo "==> Konfigurace UFW firewallu..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  comment "SSH"
ufw allow 80/tcp  comment "HTTP"
ufw allow 443/tcp comment "HTTPS"
ufw --force enable
ufw status verbose

echo ""
echo "==> Bootstrap dokončen!"
echo ""
echo "Další kroky:"
echo "  1. Přihlaste se jako ${TARGET_USER}:"
echo "       ssh ${TARGET_USER}@<IP-serveru>"
echo "  2. Naklonujte repozitář:"
echo "       git clone <repo-url> ~/gotosocial-vps"
echo "  3. Spusťte instalaci (jako root nebo přes sudo):"
echo "       cd ~/gotosocial-vps && sudo bash scripts/install.sh"
