# Self-Hosted n8n on Google Cloud (with Docker Compose & Caddy)

Production-ready setup to deploy and run self-hosted [n8n](https://n8n.io/) on a **Google Compute Engine (GCE) VM** with **PostgreSQL**, automatic **Let's Encrypt SSL/TLS** via **Caddy**, and domain DNS managed in **AWS Route 53**.

---

## 🏗️ Architecture

```
Internet (Users / Webhooks)
        │ (Ports 80 & 443)
        ▼
 ┌─────────────── Google Cloud Compute Engine VM ────────────────┐
 │                                                               │
 │  ┌─────────────────────────────────────────────────────────┐  │
 │  │                 Caddy Reverse Proxy                     │  │
 │  │          (Automatic Let's Encrypt HTTPS / TLS)          │  │
 │  └────────────────────────────┬────────────────────────────┘  │
 │                               │ internal docker network       │
 │                               ▼                               │
 │  ┌─────────────────────────────────────────────────────────┐  │
 │  │                     n8n Container                       │  │
 │  │        (Workflow Engine, Queue/Executions, API)         │  │
 │  └────────────────────────────┬────────────────────────────┘  │
 │                               │ internal docker network       │
 │                               ▼                               │
 │  ┌─────────────────────────────────────────────────────────┐  │
 │  │                  PostgreSQL Container                   │  │
 │  │               (Persistent Execution State)              │  │
 │  └─────────────────────────────────────────────────────────┘  │
 │                                                               │
 │  Persistent Volumes: n8n_data, postgres_data, caddy_data      │
 └───────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Breakdown (Optimized for $10/mo GCP Credit)

| Component | Configuration | Monthly Cost | Note |
| :--- | :--- | :--- | :--- |
| **Compute VM** | `e2-micro` (2 vCPU, 1 GB RAM) | **$0.00** | Covered by GCP Always Free Tier (us-central1, us-east1, us-west1) |
| **Boot Disk** | 30 GB Standard Persistent Disk | **$0.00** | Covered by GCP Always Free Tier |
| **Static External IPv4** | 1 Reserved Static IP | **~$3.65** | Fully covered by your $10/mo credit |
| **Egress / Webhooks** | Outbound network traffic | **~$0.10 - $0.50** | Fully covered by your $10/mo credit |
| **SSL / HTTPS (Caddy)** | In-container reverse proxy | **$0.00** | Open source / automated |
| **Total Out-of-Pocket** | | **$0.00 / month** | **100% Free** (You keep ~$5.85 credit spare) |

---

## 🚀 Step-by-Step Deployment Guide

### Step 1: Create Google Compute Engine (GCE) VM

1. Go to [Google Cloud Console -> Compute Engine -> VM instances](https://console.cloud.google.com/compute/instances).
2. Click **Create Instance**:
   - **Name**: `n8n-server`
   - **Region**: `us-central1` (Iowa), `us-east1` (S. Carolina), or `us-west1` (Oregon) *(Required for Free Tier)*
   - **Machine Configuration**: `E2` series -> `e2-micro` (2 vCPU, 1 GB RAM).
   - **Boot Disk**: Click *Change* -> OS: **Ubuntu** (Version: Ubuntu 24.04 LTS or 22.04 LTS) -> **Boot disk type**: **Standard persistent disk** -> Size: **30 GB** (100% Free Tier).
   - **Firewall**: Check both **"Allow HTTP traffic"** and **"Allow HTTPS traffic"**.
3. Click **Create**.

---

### Step 2: Reserve a Static External IP on Google Cloud

1. Go to [VPC Network -> IP addresses](https://console.cloud.google.com/networking/addresses).
2. In the list, find the row with your `n8n-server` (Type: *Ephemeral*).
3. Click the **three dots (`...`)** on the right side $\rightarrow$ select **Promote to static IP address**.
4. Name it `n8n-static-ip` and click **Reserve**.
5. Note down your static IPv4 address (e.g. `34.xxx.xxx.xxx`).

---

### Step 3: Point Your Domain in AWS Route 53

1. Log into your [AWS Route 53 Console](https://console.aws.amazon.com/route53/).
2. Select your **Hosted Zone** for your domain (e.g. `yourdomain.com`).
3. Click **Create Record**:
   - **Record name**: `n8n` (or whatever subdomain you prefer, e.g. `n8n.yourdomain.com`)
   - **Record type**: `A - Routes traffic to an IPv4 address and some AWS resources`
   - **Value**: Paste your **Google Cloud Static External IP** (from Step 2).
   - **TTL**: `300` (5 minutes)
4. Click **Create records**.

---

### Step 4: Connect to VM & Run Setup

1. In Google Cloud Console, click the **SSH** button next to your `n8n-server` VM.
2. (If git is not installed) Install git:
   ```bash
   sudo apt update && sudo apt install -y git
   ```
3. Clone this repository onto the VM:
   ```bash
   git clone https://github.com/manshanchiu/self-n8n.git
   cd self-n8n
   ```
4. Run the automated VM setup script (installs Docker, Docker Compose plugin, and sets up 2GB swap space):
   ```bash
   sudo ./scripts/setup-vm.sh
   ```

---

### Step 5: Configure Environment Variables

1. Copy the template `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Generate a random 32-byte encryption key:
   ```bash
   openssl rand -hex 32
   ```
3. Open `.env` in a text editor:
   ```bash
   nano .env
   ```
   Fill in your configuration:
   - `DOMAIN_NAME`: Your root domain (e.g. `yourdomain.com`)
   - `SUBDOMAIN`: Your subdomain (e.g. `n8n`)
   - `SSL_EMAIL`: Your email (used for Let's Encrypt certificate notifications)
   - `POSTGRES_PASSWORD`: Choose a secure password for PostgreSQL
   - `N8N_ENCRYPTION_KEY`: Paste the 32-byte hex key generated from step 2

   *(Press `Ctrl + O` then `Enter` to save in nano, and `Ctrl + X` to exit).*

---

### Step 6: Start the Stack

Launch all services in the background:
```bash
docker compose up -d
```

Verify that all containers are healthy and running:
```bash
docker compose ps
```

Check the logs to verify Caddy has automatically acquired your SSL certificate:
```bash
docker compose logs -f caddy
```

---

### Step 7: Initial Setup in Browser

Open your browser and visit:
```
https://n8n.yourdomain.com
```
1. Create your **n8n Owner account** (Email & Password).
2. You now have a fully functional, self-hosted n8n instance with auto-renewing HTTPS!

---

## 🛠️ Maintenance & Operations

### Updating n8n & Containers
Run the included update script to safely pull latest images, recreate containers, and prune old images:
```bash
./scripts/update.sh
```
> [!TIP]
> For a detailed walkthrough on version pinning, major version upgrades, PostgreSQL upgrades, and rollback procedures, check out the **[UPGRADE.md](file:///Users/roychiu/Desktop/personal_projects/self-n8n/UPGRADE.md)** guide.


### Database Backups
Create an immediate compressed PostgreSQL backup:
```bash
./scripts/backup-db.sh
```
*Backups are saved to `./backups/` and automatically rotated after 7 days.*

#### Automated Daily Backups via Cron:
To run a daily backup at 2:00 AM, edit crontab:
```bash
crontab -e
```
Add the line:
```bash
0 2 * * * /home/$USER/self-n8n/scripts/backup-db.sh > /dev/null 2>&1
```

### Useful Commands
- **View n8n logs**: `docker compose logs -f n8n`
- **View Caddy logs**: `docker compose logs -f caddy`
- **Restart stack**: `docker compose restart`
- **Stop stack**: `docker compose down`

---

## 🔒 Security Best Practices
- Keep your `N8N_ENCRYPTION_KEY` backed up securely. If lost, encrypted credentials cannot be recovered.
- Ensure your `.env` is never committed to a public git repository (already configured in `.gitignore`).
- Only ports `22` (SSH), `80` (HTTP), and `443` (HTTPS) should be open to the internet in GCP firewall. The PostgreSQL port (`5432`) is kept private inside Docker's internal network.
