#!/bin/bash
set -euo pipefail

# ==============================================================================
# n8n Stack Update Script
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================================="
echo " Updating n8n, PostgreSQL, and Caddy..."
echo "========================================================="

cd "$ROOT_DIR"

# 1. Trigger a database backup before updating
if [ -f "${SCRIPT_DIR}/backup-db.sh" ]; then
  echo "[+] Running safety database backup before upgrade..."
  bash "${SCRIPT_DIR}/backup-db.sh"
fi

# 2. Pull latest images
echo "[+] Pulling latest Docker images..."
docker compose pull

# 3. Recreate and restart containers
echo "[+] Restarting containers with updated images..."
docker compose up -d

# 4. Prune old dangling images
echo "[+] Pruning unused Docker images..."
docker image prune -f

echo "========================================================="
echo " [✓] Update completed successfully!"
echo " Check status with: docker compose ps"
echo " View logs with:    docker compose logs -f"
echo "========================================================="
