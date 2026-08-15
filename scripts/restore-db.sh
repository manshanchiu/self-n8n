#!/bin/bash
set -euo pipefail

# ==============================================================================
# n8n PostgreSQL Database Restore Script
# Restores a specified .sql.gz backup file into PostgreSQL
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${ROOT_DIR}/backups"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_backup_file.sql.gz>"
  echo ""
  echo "Available backups in ${BACKUP_DIR}:"
  ls -lh "${BACKUP_DIR}"/*.sql.gz 2>/dev/null || echo "  (No backups found)"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "[-] Error: Backup file '$BACKUP_FILE' not found."
  exit 1
fi

echo "[+] Sourcing environment variables..."
if [ -f "${ROOT_DIR}/.env" ]; then
  export $(grep -E '^(POSTGRES_USER|POSTGRES_DB)=' "${ROOT_DIR}/.env" | xargs)
else
  echo "[-] Error: .env file not found in ${ROOT_DIR}"
  exit 1
fi

echo "========================================================="
echo " WARNING: This will overwrite the current '${POSTGRES_DB}' database!"
echo " Restoring from: ${BACKUP_FILE}"
echo "========================================================="
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "[-] Restore cancelled."
  exit 1
fi

echo "[+] Stopping n8n to prevent database writes..."
docker compose -f "${ROOT_DIR}/docker-compose.yml" stop n8n

echo "[+] Restoring database from backup..."
gunzip -c "$BACKUP_FILE" | docker compose -f "${ROOT_DIR}/docker-compose.yml" exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"

echo "[+] Restarting n8n..."
docker compose -f "${ROOT_DIR}/docker-compose.yml" start n8n

echo "========================================================="
echo " [✓] Database restore completed successfully!"
echo " Check n8n logs: docker compose logs -f n8n"
echo "========================================================="
