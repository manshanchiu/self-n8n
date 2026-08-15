# n8n Upgrade & Maintenance Guide

This document provides a comprehensive guide for upgrading your self-hosted **n8n**, **PostgreSQL**, and **Caddy** stack on Google Cloud VM, including version pinning, breaking changes handling, and disaster recovery/rollback procedures.

---

## 📋 Table of Contents
1. [Upgrade Strategy & Best Practices](#1-upgrade-strategy--best-practices)
2. [Standard 1-Click Upgrade (Minor & Patch)](#2-standard-1-click-upgrade-minor--patch)
3. [Pinning Specific n8n Versions](#3-pinning-specific-n8n-versions)
4. [Major Version Upgrades (Breaking Changes)](#4-major-version-upgrades-breaking-changes)
5. [Upgrading PostgreSQL Database](#5-upgrading-postgresql-database)
6. [Rollback & Disaster Recovery](#6-rollback--disaster-recovery)

---

## 1. Upgrade Strategy & Best Practices

> [!IMPORTANT]
> **Always ensure you have a fresh database backup before running any upgrade.**
> Our included `update.sh` script automatically triggers a backup into `./backups/` before pulling new container images.

- **Check Release Notes First**: Review the official [n8n Release Notes](https://github.com/n8n-io/n8n/releases) or the [n8n Forum Release Announcements](https://community.n8n.io/c/announcements/release-notes/19) for any deprecations or node parameter changes.
- **Production Tip**: In critical production environments, consider pinning your version (e.g. `n8nio/n8n:1.80.0`) instead of using `:latest` so you have total control over when upgrades happen.

---

## 2. Standard 1-Click Upgrade (Minor & Patch)

For standard rolling updates when using `latest` or updated tags:

1. **SSH into your VM**:
   ```bash
   cd ~/self-n8n
   ```

2. **Run the update script**:
   ```bash
   ./scripts/update.sh
   ```

### What `update.sh` does automatically:
1. Triggers `./scripts/backup-db.sh` to save a timestamped `n8n_backup_YYYYMMDD_HHMMSS.sql.gz` snapshot in `./backups/`.
2. Runs `docker compose pull` to download new Docker images for n8n, PostgreSQL, and Caddy.
3. Runs `docker compose up -d` to recreate containers with the new image.
4. n8n automatically runs any pending database migrations during its startup.
5. Runs `docker image prune -f` to reclaim disk space on your VM by deleting old untagged image layers.

---

## 3. Pinning Specific n8n Versions

If you want to upgrade to a specific verified n8n version rather than `:latest`:

1. Open `docker-compose.yml` in an editor:
   ```yaml
   services:
     n8n:
       # Change :latest to a specific version tag, e.g., :1.80.0
       image: docker.n8n.io/n8nio/n8n:1.80.0
   ```
2. Apply the change:
   ```bash
   # Run backup first
   ./scripts/backup-db.sh

   # Pull and restart
   docker compose pull n8n
   docker compose up -d n8n
   ```
3. Check logs to confirm successful startup and migration:
   ```bash
   docker compose logs -f n8n
   ```

---

## 4. Major Version Upgrades (Breaking Changes)

When n8n releases a major version with breaking changes or migration steps:

1. **Review Migration Notes**: Check the release documentation for breaking node changes or database requirements.
2. **Export Workflows & Credentials (Extra Safety)**:
   You can export all workflows and credentials directly via n8n CLI inside the container:
   ```bash
   # Export all workflows to a JSON file
   docker compose exec n8n n8n export:workflow --all --output=/home/node/.n8n/workflows_export.json

   # Export all credentials (decrypted with your N8N_ENCRYPTION_KEY)
   docker compose exec n8n n8n export:credentials --all --decrypted --output=/home/node/.n8n/credentials_export.json
   ```
3. **Execute Upgrade**:
   ```bash
   ./scripts/update.sh
   ```
4. **Verify Canvas & Workflows**:
   - Log into `https://n8n.yourdomain.com`.
   - Test your most critical webhook and scheduled workflows.

---

## 5. Upgrading PostgreSQL Database

If you need to upgrade the major version of PostgreSQL (e.g. from `postgres:16-alpine` to `postgres:17-alpine`):

> [!WARNING]
> PostgreSQL does not allow direct in-place major version upgrades on the same raw data directory (`postgres_data`). Follow these export-import steps:

1. **Create a full database dump**:
   ```bash
   ./scripts/backup-db.sh
   ```
   Note the latest file in `./backups/` (e.g., `backups/n8n_backup_20260815_120000.sql.gz`).

2. **Stop the entire stack**:
   ```bash
   docker compose down
   ```

3. **Backup and remove old Postgres volume**:
   ```bash
   # Remove the old Postgres volume to allow the new version to initialize cleanly
   docker volume rm self-n8n_postgres_data
   ```

4. **Update `docker-compose.yml`**:
   Change `postgres:16-alpine` to `postgres:17-alpine`.

5. **Start PostgreSQL only**:
   ```bash
   docker compose up -d postgres
   ```

6. **Restore the database dump**:
   ```bash
   ./scripts/restore-db.sh backups/n8n_backup_20260815_120000.sql.gz
   ```

7. **Start the rest of the stack**:
   ```bash
   docker compose up -d
   ```

---

## 6. Rollback & Disaster Recovery

If an upgrade fails, causes errors, or breaks a workflow:

### Step 1: Identify the Previous Working Backup
List your backups:
```bash
ls -lh backups/
```

### Step 2: Roll Back n8n Image
If you pinned the version, revert the tag in `docker-compose.yml` to the previous version (e.g. change `:1.81.0` back to `:1.80.0`).

### Step 3: Restore Database Snapshot
Use the automated restore script:
```bash
./scripts/restore-db.sh backups/n8n_backup_YYYYMMDD_HHMMSS.sql.gz
```

### Step 4: Restart and Verify
```bash
docker compose up -d
docker compose logs -f n8n
```
The stack will be completely restored to its pre-upgrade state.
