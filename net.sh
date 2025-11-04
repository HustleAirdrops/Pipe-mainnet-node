#!/bin/bash
set -e

# -------------------- COLORS -------------------- A
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
echo_green() { echo -e "${GREEN}$1${NC}"; }
echo_yellow() { echo -e "${YELLOW}$1${NC}"; }
echo_red() { echo -e "${RED}$1${NC}"; }

# -------------------- ROOT CHECK --------------------
if [[ $EUID -ne 0 ]]; then
   echo_red "Please run as root (sudo bash pipe_systemd_setup.sh)"
   exit 1
fi

# -------------------- SETUP DIRECTORY --------------------
INSTALL_DIR="/opt/pipe"
echo_green "📁 Setting up Pipe Node directory at: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/cache"
cd "$INSTALL_DIR"

# -------------------- UPDATE SYSTEM --------------------
echo_green ">> Updating system and installing dependencies..."
apt update -y >/dev/null 2>&1
apt install -y curl unzip ufw >/dev/null 2>&1
echo_green "✅ Dependencies installed"

# -------------------- DOWNLOAD PIPE BINARY --------------------
if [[ ! -f "$INSTALL_DIR/pop" ]]; then
    echo_green ">> Downloading Pipe POP binary..."
    curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o pop
    chmod +x pop
else
    echo_yellow "⚠️ POP binary already exists, skipping download."
fi

# -------------------- CREATE .ENV --------------------
if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    echo_green ">> Creating .env configuration file..."
    LOCATION=$(curl -s ipinfo.io | grep '"city"' | cut -d'"' -f4)
    COUNTRY=$(curl -s ipinfo.io | grep '"country"' | cut -d'"' -f4)
    NODE_LOCATION="${LOCATION}, ${COUNTRY}"

    read -p "Enter your Solana Wallet Address: " WALLET
    read -p "Enter your Node Name: " NODE_NAME
    read -p "Enter your Email: " NODE_EMAIL

    cat > "$INSTALL_DIR/.env" <<EOF
NODE_SOLANA_PUBLIC_KEY=${WALLET}
NODE_NAME=${NODE_NAME}
NODE_EMAIL="${NODE_EMAIL}"
NODE_LOCATION="${NODE_LOCATION}"
MEMORY_CACHE_SIZE_MB=512
DISK_CACHE_SIZE_GB=25
DISK_CACHE_PATH=./cache
HTTP_PORT=80
HTTPS_PORT=443
UPNP_ENABLED=false
EOF
    chmod 600 "$INSTALL_DIR/.env"
    echo_green "✅ .env file created"
else
    echo_yellow "⚠️ Existing .env found, skipping creation."
fi

# -------------------- CONFIGURE FIREWALL --------------------
echo_green ">> Configuring firewall (UFW)..."
ufw allow 22 >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
echo_green "✅ Firewall configured"

# -------------------- CREATE SYSTEMD SERVICE --------------------
echo_green ">> Creating systemd service for Pipe..."
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

# -------------------- ENABLE AND START SERVICE --------------------
systemctl daemon-reload
systemctl enable pipe
systemctl restart pipe
sleep 3

# -------------------- VERIFY STATUS --------------------
if systemctl is-active --quiet pipe; then
    echo_green "✅ Pipe Node started successfully!"
    echo_yellow "🟢 To view logs: sudo journalctl -u pipe -f"
else
    echo_red "❌ Failed to start Pipe Node. Run: sudo journalctl -u pipe -xe"
fi

echo_green "🎉 Setup complete — your node will auto-start on reboot!"
