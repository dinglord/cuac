#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_DIR="${PROJECT_DIR:-.}"
BACKUP_DIR="$PROJECT_DIR/backups"
SECRETS_DIR="$PROJECT_DIR/secrets"
DB_NAME="$(grep -E '^POSTGRES_DB=' .env | cut -d= -f2)"
DB_USER="$(cat "$SECRETS_DIR/db_user")"
DB_PASS="$(cat "$SECRETS_DIR/db_password")"

TS="$(date +%F_%H%M%S)"
OUT_DIR="$BACKUP_DIR/guac_backup_$TS"
TARBALL="$BACKUP_DIR/guac_$TS.tar.gz"
RETENTION="${RETENTION:-7}"

mkdir -p "$OUT_DIR" "$BACKUP_DIR"

echo "[*] Dumping PostgreSQL..."
docker exec -e PGPASSWORD="$DB_PASS" guac-postgres \
  pg_dump -U "$DB_USER" "$DB_NAME" > "$OUT_DIR/guacamole_db.sql"

echo "[*] Archiving config and recordings..."
tar czf "$OUT_DIR/config.tar.gz" -C "$PROJECT_DIR" config
tar czf "$OUT_DIR/recordings.tar.gz" -C "$PROJECT_DIR" recordings || true

echo "[*] Capturing compose + env template..."
cp docker-compose.yml "$OUT_DIR/"
cp .env.template "$OUT_DIR/"

echo "[*] Bundling..."
tar czf "$TARBALL" -C "$OUT_DIR" .
echo "[*] Backup written: $TARBALL"

echo "[*] Retention: keeping last $RETENTION backups"
ls -1t "$BACKUP_DIR"/guac_*.tar.gz | tail -n +$((RETENTION+1)) | xargs -r rm -f
echo "[*] Done."