#!/bin/bash
set -e

# -------------------- COLORS --------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_green() { echo -e "${GREEN}$1${NC}"; }
echo_yellow() { echo -e "${YELLOW}$1${NC}"; }
echo_red() { echo -e "${RED}$1${NC}"; }

log() { echo -e "${GREEN}[$1]${NC} $2"; }

# -------------------- CHECK ROOT --------------------
if [[ $EUID -ne 0 ]]; then
   echo_red "Please run as root (use: sudo bash install_pipe.sh)"
   exit 1
fi

# -------------------- INSTALL UNZIP --------------------
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        log "INFO" "⚠️ 'unzip' not found, installing..."
        if command -v apt &> /dev/null; then
            sudo apt update -y && sudo apt install -y unzip
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip
        elif command -v apk &> /dev/null; then
            sudo apk add unzip
        else
            log "ERROR" "❌ Could not install 'unzip' (unknown package manager)."
            exit 1
        fi
    fi
}

# -------------------- UNZIP & MOVE .env --------------------
unzip_files() {
    ZIP_FILE=$(find "$HOME" -maxdepth 1 -type f -name "*.zip" | head -n 1)
   
    if [ -n "$ZIP_FILE" ]; then
        log "INFO" "📂 Found ZIP file: $ZIP_FILE, unzipping to $HOME ..."
        install_unzip
        unzip -o "$ZIP_FILE" -d "$HOME" >/dev/null 2>&1

        # Recursively find .env (even if inside subfolder)
        FOUND_ENV=$(find "$HOME" -type f -name ".env" | head -n 1)

        if [ -n "$FOUND_ENV" ]; then
            sudo mkdir -p /opt/pipe
            sudo mv "$FOUND_ENV" /opt/pipe/.env
            sudo chmod 600 /opt/pipe/.env
            JUST_EXTRACTED_ENV=true
            log "INFO" "✅ Moved .env to /opt/pipe/.env"
        else
            log "WARN" "⚠️ No .env file found inside ZIP"
        fi

        ls -l "$HOME"
        if [ -f "/opt/pipe/.env" ]; then
            log "INFO" "✅ Successfully extracted and moved .env file"
        else
            log "WARN" "⚠️ Extraction completed, but .env not found at final location"
        fi
    else
        log "WARN" "⚠️ No ZIP file found in $HOME, proceeding without unzipping"
    fi
}

# -------------------- MAIN SETUP --------------------
echo_green ">> Updating system & installing dependencies..."
apt update -y >/dev/null 2>&1
apt install -y curl ufw >/dev/null 2>&1

echo_green ">> Setting up /opt/pipe directory..."
mkdir -p /opt/pipe/cache
cd /opt/pipe

# -------------------- DOWNLOAD POP --------------------
if [[ ! -f "/opt/pipe/pop" ]]; then
    echo_green ">> Downloading latest Pipe POP binary..."
    curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o /opt/pipe/pop
    chmod +x /opt/pipe/pop
else
    echo_yellow ">> POP binary already exists, skipping download."
fi

# -------------------- UNZIP .env OR TAKE INPUT --------------------
unzip_files

if [ ! -f "/opt/pipe/.env" ]; then
    echo_green ">> No .env found, creating new one..."
    read -p "Enter your Solana wallet address: " WALLET
    read -p "Enter your Node Name: " NODE_NAME
    read -p "Enter your Email: " NODE_EMAIL

    LOCATION=$(curl -s ipinfo.io | grep '"city"' | cut -d'"' -f4)
    COUNTRY=$(curl -s ipinfo.io | grep '"country"' | cut -d'"' -f4)
    NODE_LOCATION="${LOCATION}, ${COUNTRY}"

    cat > /opt/pipe/.env <<EOF
# Wallet for earnings
NODE_SOLANA_PUBLIC_KEY=${WALLET}

# Node identity
NODE_NAME=${NODE_NAME}
NODE_EMAIL="${NODE_EMAIL}"
NODE_LOCATION="${NODE_LOCATION}"

# Cache configuration
MEMORY_CACHE_SIZE_MB=512
DISK_CACHE_SIZE_GB=25
DISK_CACHE_PATH=./cache

# Network ports
HTTP_PORT=80
HTTPS_PORT=443

# Home network auto port forwarding (disable on VPS/servers)
UPNP_ENABLED=false
EOF
    chmod 600 /opt/pipe/.env
    echo_green "✅ Created new .env at /opt/pipe/.env"
else
    echo_green "✅ Existing .env detected, skipping manual input"
fi

# -------------------- FIREWALL --------------------
echo_green ">> Configuring firewall..."
ufw allow 22 >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw --force enable >/dev/null 2>&1
ufw status | grep "Status"

# -------------------- SYSTEMD SERVICE --------------------
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

# -------------------- ENABLE SERVICE --------------------
systemctl daemon-reload
systemctl enable pipe
systemctl restart pipe

sleep 3
if systemctl is-active --quiet pipe; then
    echo_green "✅ Pipe Node started successfully!"
else
    echo_red "❌ Failed to start Pipe Node. Check logs with: sudo journalctl -u pipe -xe"
fi
