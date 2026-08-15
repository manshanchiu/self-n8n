#!/bin/bash
set -euo pipefail

# ==============================================================================
# Google Cloud VM Provisioning Script for self-hosted n8n
# Supports: Ubuntu 22.04 / 24.04 & Debian 11 / 12
# ==============================================================================

echo "========================================================="
echo " Starting VM setup for n8n on Google Cloud..."
echo "========================================================="

# 1. Check Root / Sudo
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root or with sudo: sudo ./scripts/setup-vm.sh"
  exit 1
fi

# 2. Update and install base prerequisites
echo "[+] Updating apt repositories..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release ufw openssl

# 3. Configure 2GB Swap file (Critical for e2-micro/e2-small stability)
if [ ! -f /swapfile ]; then
  echo "[+] Creating 2GB swap file to optimize RAM usage..."
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "vm.swappiness=10" >> /etc/sysctl.conf
  sysctl -p
  echo "[✓] Swap file created successfully."
else
  echo "[i] Swap file already exists. Skipping."
fi

# 4. Install official Docker Engine & Docker Compose Plugin
if ! command -v docker &> /dev/null; then
  echo "[+] Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  
  DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
  curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DISTRO} \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  systemctl enable docker
  systemctl start docker
  echo "[✓] Docker installed successfully."
else
  echo "[i] Docker is already installed."
fi

# 5. Add current non-root user to docker group if SUDO_USER is set
if [ -n "${SUDO_USER:-}" ]; then
  usermod -aG docker "$SUDO_USER"
  echo "[✓] Added $SUDO_USER to the 'docker' group."
fi

# 6. Basic UFW Firewall (Optional helper)
echo "[+] Checking firewall status..."
if command -v ufw &> /dev/null; then
  ufw allow 22/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  echo "[✓] Allowed ports 22, 80, 443 in UFW (Ensure GCP VPC firewall rules also allow 80 & 443)."
fi

echo "========================================================="
echo " [✓] VM Setup Complete!"
echo " Next Steps:"
echo " 1. Copy .env.example to .env: cp .env.example .env"
echo " 2. Generate encryption key: openssl rand -hex 32"
echo " 3. Edit .env with your domain, passwords, and encryption key"
echo " 4. Start the stack: docker compose up -d"
echo "========================================================="
