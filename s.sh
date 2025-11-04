#!/bin/bash
set -e

# -------------------- COLORS --------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo_green() { echo -e "${GREEN}$1${NC}"; }
echo_yellow() { echo -e "${YELLOW}$1${NC}"; }
echo_red() { echo -e "${RED}$1${NC}"; }

# -------------------- CHECK ROOT --------------------
if [[ $EUID -ne 0 ]]; then
   echo_red "Please run as root (use: sudo bash install_pipe.sh)"
   exit 1
fi

# -------------------- INSTALL DEPENDENCIES --------------------
echo_green ">> Updating system & installing dependencies..."
apt update -y >/dev/null 2>&1
apt install -y curl nano ufw >/dev/null 2>&1

# -------------------- SETUP FOLDER --------------------
echo_green ">> Setting up /opt/pipe directory..."
mkdir -p /opt/pipe/cache
cd /opt/pipe

# -------------------- DOWNLOAD POP BINARY --------------------
if [[ ! -f "/opt/pipe/pop" ]]; then
    echo_green ">> Downloading latest Pipe POP binary..."
    curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o /opt/pipe/pop
    chmod +x /opt/pipe/pop
else
    echo_yellow ">> POP binary already exists, skipping download."
fi

# -------------------- USER INPUT --------------------
echo_green ">> Enter details for your node setup:"
read -p "Enter your Solana wallet address: " WALLET
read -p "Enter your Node Name: " NODE_NAME
read -p "Enter your Email: " NODE_EMAIL

# -------------------- AUTO DETECT LOCATION --------------------
echo_green ">> Detecting location..."
LOCATION=$(curl -s ipinfo.io | grep '"city"' | cut -d'"' -f4)
COUNTRY=$(curl -s ipinfo.io | grep '"country"' | cut -d'"' -f4)
if [[ -z "$LOCATION" ]]; then
    LOCATION="Unknown"
fi
NODE_LOCATION="$LOCATION, $COUNTRY"
echo_green ">> Detected location: $NODE_LOCATION"

# -------------------- CREATE .env FILE --------------------
echo_green ">> Creating /opt/pipe/.env file..."
cat > /opt/pipe/.env <<EOF
# Wallet for earnings
NODE_SOLANA_PUBLIC_KEY=${WALLET}

# Node identity
NODE_NAME=${NODE_NAME}
NODE_EMAIL="${NODE_EMAIL}"
NODE_LOCATION="${NODE_LOCATION}"

# Cache configuration
MEMORY_CACHE_SIZE_MB=512
DISK_CACHE_SIZE_GB=100
DISK_CACHE_PATH=./cache

# Network ports
HTTP_PORT=80
HTTPS_PORT=443

# Home network auto port forwarding (disable on VPS/servers)
UPNP_ENABLED=false
EOF

# -------------------- FIREWALL SETUP --------------------
echo_green ">> Configuring firewall..."
ufw allow 22 >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
ufw status verbose | grep "Status"

# -------------------- CREATE SYSTEMD SERVICE --------------------
echo_green ">> Creating systemd service file..."
cat > /etc/systemd/system/pipe.service <<'EOF'
[Unit]
Description=Pipe Network POP Node
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/pipe
ExecStart=/bin/bash -c 'source /opt/pipe/.env && /opt/pipe/pop'
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# -------------------- ENABLE & START SERVICE --------------------
echo_green ">> Reloading systemd and enabling Pipe service..."
systemctl daemon-reload
systemctl enable pipe
systemctl restart pipe

sleep 3
if systemctl is-active --quiet pipe; then
    echo_green "✅ Pipe Node started successfully!"
    echo_green "You can monitor logs using: sudo journalctl -u pipe -f"
else
    echo_red "❌ Failed to start Pipe Node. Check logs with: sudo journalctl -u pipe -xe"
fi
