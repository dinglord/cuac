#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 backups/guac_YYYY-MM-DD_HHMMSS.tar.gz"
  exit 1
fi

BACKUP_TARBALL="$1"
cd "$(dirname "$0")/.."

PROJECT_DIR="${PROJECT_DIR:-.}"
RESTORE_DIR="$PROJECT_DIR/backups/__restore_tmp"
SECRETS_DIR="$PROJECT_DIR/secrets"
DB_NAME="$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2)"
DB_USER="$(cat "$SECRETS_DIR/db_user")"
DB_PASS="$(cat "$SECRETS_DIR/db_password")"

rm -rf "$RESTORE_DIR"
mkdir -p "$RESTORE_DIR"
tar xzf "$BACKUP_TARBALL" -C "$RESTORE_DIR"

echo "[*] Stopping stack..."
docker compose down

echo "[*] Resetting database volume (keeping config/recordings)..."
sudo rm -rf "$PROJECT_DIR/db/"*

echo "[*] Starting clean stack..."
docker compose up -d
sleep 5

echo "[*] Restoring config and recordings..."
tar xzf "$RESTORE_DIR/config.tar.gz" -C "$PROJECT_DIR"
[[ -f "$RESTORE_DIR/recordings.tar.gz" ]] && tar xzf "$RESTORE_DIR/recordings.tar.gz" -C "$PROJECT_DIR" || true
docker compose restart guacamole

echo "[*] Restoring database..."
docker exec -i -e PGPASSWORD="$DB_PASS" guac-postgres \
  psql -U "$DB_USER" -d "$DB_NAME" < "$RESTORE_DIR/guacamole_db.sql"

echo "[*] Final restart..."
docker compose restart

echo "[*] Cleanup..."
rm -rf "$RESTORE_DIR"
echo "[*] Restore complete."