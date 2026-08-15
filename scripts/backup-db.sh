#!/bin/bash
set -euo pipefail

# ==============================================================================
# n8n PostgreSQL Database Backup Script
# Creates compressed dumps and keeps the last 7 days of backups
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${ROOT_DIR}/backups"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_FILE="${BACKUP_DIR}/n8n_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[+] Sourcing environment variables..."
if [ -f "${ROOT_DIR}/.env" ]; then
  # Load POSTGRES_USER and POSTGRES_DB from .env
  export $(grep -E '^(POSTGRES_USER|POSTGRES_DB)=' "${ROOT_DIR}/.env" | xargs)
else
  echo "[-] Error: .env file not found in ${ROOT_DIR}"
  exit 1
fi

echo "[+] Creating PostgreSQL database backup to ${BACKUP_FILE}..."
docker compose -f "${ROOT_DIR}/docker-compose.yml" exec -T postgres pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${BACKUP_FILE}"

echo "[✓] Backup created successfully ($(du -h "${BACKUP_FILE}" | cut -f1))"

echo "[+] Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -type f -name "n8n_backup_*.sql.gz" -mtime +7 -exec rm -f {} \;

echo "[✓] Backup routine completed."
