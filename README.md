# GoToSocial VPS – Instalační příručka

Tento repozitář obsahuje konfigurační soubory a skripty pro nasazení instance [GoToSocial](https://gotosocial.org/) na VPS pomocí Dockeru a reverzního proxy Nginx.

## Obsah

- [Požadavky](#požadavky)
- [Struktura repozitáře](#struktura-repozitáře)
- [Instalace](#instalace)
- [Konfigurace](#konfigurace)
- [Nginx](#nginx)
- [Správa instance](#správa-instance)
- [Zálohy](#zálohy)

---

## Požadavky

- VPS s Ubuntu 22.04 / Debian 12
- Docker a Docker Compose
- Doménové jméno s nastaveným DNS A záznamem na IP VPS
- Nginx
- Certbot (Let's Encrypt)

## Struktura repozitáře

```
gotosocial-vps/
├── docker-compose.yml       # Docker Compose konfigurace
├── .env.example             # Vzor proměnných prostředí
├── config/
│   └── config.yaml          # Konfigurační soubor GoToSocial
├── nginx/
│   └── gotosocial.conf      # Nginx konfigurace (reverzní proxy)
└── scripts/
    ├── install.sh           # Skript pro první instalaci
    ├── update.sh            # Aktualizace GoToSocial
    └── backup.sh            # Záloha dat
```

## Instalace

### 1. Příprava serveru

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose nginx certbot python3-certbot-nginx
sudo systemctl enable --now docker
```

### 2. Klonování repozitáře

```bash
git clone ssh://git@git.arch-linux.cz:29418/Archos/gotosocial-vps.git
cd gotosocial-vps
```

### 3. Nastavení proměnných prostředí

```bash
cp .env.example .env
nano .env
```

Vyplňte hodnoty – zejména `GTS_HOST` (vaše doména) a `GTS_DB_PASSWORD`.

### 4. Spuštění

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

Nebo ručně:

```bash
mkdir -p data
docker-compose up -d
```

### 5. SSL certifikát

```bash
sudo certbot --nginx -d vase-domena.cz
```

### 6. Nginx konfigurace

```bash
sudo cp nginx/gotosocial.conf /etc/nginx/sites-available/gotosocial
sudo ln -s /etc/nginx/sites-available/gotosocial /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Konfigurace

Hlavní konfigurace se nachází v `config/config.yaml`. Nejdůležitější položky:

| Položka | Popis |
|---|---|
| `host` | Vaše doména (např. `social.example.cz`) |
| `protocol` | `https` pro produkci |
| `db-address` | Cesta k SQLite nebo adresa Postgres |
| `storage-local-base-path` | Adresář pro ukládání médií |
| `smtp-*` | Nastavení e-mailu pro notifikace |

## Nginx

Soubor `nginx/gotosocial.conf` je šablona pro reverzní proxy. Před použitím upravte:
- `server_name` – nahraďte `vase-domena.cz` vaší doménou
- Cesty k SSL certifikátům (vyplní Certbot automaticky)

## Správa instance

```bash
# Vytvoření admin účtu
docker-compose exec gotosocial /gotosocial/gotosocial admin account create \
  --username admin \
  --email admin@vase-domena.cz \
  --password "silne_heslo"

# Přiřazení admin role
docker-compose exec gotosocial /gotosocial/gotosocial admin account promote \
  --username admin

# Zobrazení logů
docker-compose logs -f gotosocial

# Restart
docker-compose restart gotosocial
```

## Zálohy

Zálohovací skript uloží data a konfiguraci do archivu:

```bash
chmod +x scripts/backup.sh
./scripts/backup.sh
```

Zálohy jsou ukládány do adresáře `backups/` ve formátu `gotosocial-backup-YYYY-MM-DD.tar.gz`.

## Aktualizace

```bash
chmod +x scripts/update.sh
./scripts/update.sh
```

Skript stáhne nejnovější obraz GoToSocial a restartuje kontejner.
