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
   echo_red "Please run as root (use: sudo bash install_pipe_stable.sh)"
   exit 1
fi

# -------------------- CHECK OR CREATE .env FIRST --------------------
check_env() {
    if [ -f "$HOME/.env" ]; then
        echo_green "✅ Found .env in HOME, moving it to /opt/pipe/.env"
        mkdir -p /opt/pipe
        mv -f "$HOME/.env" /opt/pipe/.env
        chmod 600 /opt/pipe/.env
    elif [ -f "/opt/pipe/.env" ]; then
        echo_green "✅ Existing /opt/pipe/.env found, reusing it."
    else
        echo_yellow "⚠️ No .env found — taking input..."
        read -p "Enter your Solana wallet address: " WALLET
        read -p "Enter your Node Name: " NODE_NAME
        read -p "Enter your Email: " NODE_EMAIL

        LOCATION=$(curl -s ipinfo.io | grep '"city"' | cut -d'"' -f4)
        COUNTRY=$(curl -s ipinfo.io | grep '"country"' | cut -d'"' -f4)
        NODE_LOCATION="${LOCATION}, ${COUNTRY}"

        mkdir -p /opt/pipe
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
    fi
}

# -------------------- INSTALL DEPENDENCIES --------------------
install_dependencies() {
    echo_green ">> Updating system & installing packages..."
    apt update -y >/dev/null 2>&1
    apt install -y build-essential wget curl ufw sudo gawk bison texinfo >/dev/null 2>&1
}

# -------------------- INSTALL GLIBC 2.39 --------------------
install_glibc() {
    if [ ! -d "/opt/glibc-2.39/lib" ]; then
        echo_yellow "⚙️ GLIBC 2.39 not found, installing..."
        
        # Work safely inside /tmp/glibc39build (isolated folder)
        mkdir -p /tmp/glibc39build
        cd /tmp/glibc39build
        
        # Clean only inside this folder, not entire /tmp
        rm -rf glibc-2.39 glibc-build glibc-2.39.tar.gz >/dev/null 2>&1

        # Download and extract source
        wget -q http://ftp.gnu.org/gnu/libc/glibc-2.39.tar.gz
        tar -xzf glibc-2.39.tar.gz

        # Prepare build folder
        mkdir glibc-build && cd glibc-build

        # Configure and compile
        ../glibc-2.39/configure --prefix=/opt/glibc-2.39 >/dev/null 2>&1
        make -j$(nproc) >/dev/null 2>&1
        make install >/dev/null 2>&1

        echo_green "✅ GLIBC 2.39 installed at /opt/glibc-2.39"
    else
        echo_green "✅ GLIBC 2.39 already installed — skipping build."
    fi
}



# -------------------- INSTALL OPENSSL 3 --------------------
install_openssl3() {
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libssl.so.3" ]; then
        echo_yellow "⚙️ Installing OpenSSL 3 runtime..."
        echo "deb http://deb.debian.org/debian bookworm main" | tee /etc/apt/sources.list.d/bookworm.list >/dev/null
        apt update -y >/dev/null 2>&1
        apt install -y libssl3 >/dev/null 2>&1
        echo_green "✅ Installed OpenSSL 3 (libssl3)"
    else
        echo_green "✅ OpenSSL 3 already installed."
    fi
}

# -------------------- DOWNLOAD PIPE BINARY --------------------
install_pipe_binary() {
    echo_green ">> Setting up /opt/pipe directory..."
    mkdir -p /opt/pipe/cache
    cd /opt/pipe

    if [[ ! -f "/opt/pipe/pop" ]]; then
        echo_green ">> Downloading latest Pipe POP binary..."
        curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o /opt/pipe/pop
        chmod +x /opt/pipe/pop
        echo_green "✅ Download complete."
    else
        echo_yellow ">> POP binary already exists, skipping download."
    fi
}

# -------------------- FIREWALL --------------------
setup_firewall() {
    echo_green ">> Configuring firewall..."
    ufw allow 22 >/dev/null 2>&1
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
}

# -------------------- CREATE SYSTEMD SERVICE --------------------
create_service() {
    cat > /etc/systemd/system/pipe.service <<'EOF'
[Unit]
Description=Pipe Network POP Node
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/pipe
ExecStart=/bin/bash -c 'source /opt/pipe/.env && /opt/glibc-2.39/lib/ld-linux-x86-64.so.2 --library-path /opt/glibc-2.39/lib:/usr/lib/x86_64-linux-gnu /opt/pipe/pop'
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable pipe
    systemctl restart pipe

    sleep 3
    if systemctl is-active --quiet pipe; then
        echo_green "✅ Pipe Node started successfully!"
    else
        echo_red "❌ Failed to start Pipe Node. Check logs with: sudo journalctl -u pipe -xe"
    fi
}

# -------------------- MAIN EXECUTION --------------------
check_env
install_dependencies
install_glibc
install_openssl3
install_pipe_binary
setup_firewall
create_service

echo_green "🎉 Installation Complete! Use these commands:"
echo_green "  sudo systemctl status pipe      # Check status"
echo_green "  sudo journalctl -u pipe -f      # Live logs"
echo_green "  cd /opt/pipe && ./pop status    # Node status"
