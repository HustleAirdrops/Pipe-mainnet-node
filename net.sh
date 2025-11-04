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

# -------------------- ROOT CHECK --------------------
if [[ $EUID -ne 0 ]]; then
   echo_red "Please run as root (sudo bash install_pipe.sh)"
   exit 1
fi

# -------------------- INSTALL DOCKER --------------------
echo_green ">> Installing Docker safely..."
apt update -y >/dev/null 2>&1
apt install -y docker.io >/dev/null 2>&1
systemctl enable --now docker >/dev/null 2>&1
echo_green "✅ Docker installed & running"

# -------------------- CREATE PERSISTENT CONTAINER --------------------
if docker ps -a --format '{{.Names}}' | grep -q '^pipe-node$'; then
    echo_yellow "⚠️ Container 'pipe-node' already exists, skipping creation."
else
    echo_green ">> Creating persistent Debian container (pipe-node)..."
    docker run -dit \
        --name pipe-node \
        -v "$PWD":/app \
        -w /app \
        --restart unless-stopped \
        debian:testing bash
    echo_green "✅ Container 'pipe-node' created successfully."
fi

# -------------------- SETUP INSIDE CONTAINER --------------------
echo_green ">> Preparing inside container..."
docker exec pipe-node bash -c "
set -e
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
apt update -y >/dev/null 2>&1
apt install -y libc6 curl iputils-ping dnsutils unzip ufw >/dev/null 2>&1

cd /app
echo '>>> Setting up /app/pipe directory...'
mkdir -p /app/pipe/cache
cd /app/pipe

# -------------------- DOWNLOAD POP --------------------
if [[ ! -f '/app/pipe/pop' ]]; then
    echo '>>> Downloading Pipe POP binary...'
    curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o pop
    chmod +x pop
else
    echo '>>> POP binary already exists, skipping download.'
fi

# -------------------- CREATE .env --------------------
if [ ! -f '/app/pipe/.env' ]; then
    echo '>>> Creating .env file...'
    read -p 'Enter Solana Wallet Address: ' WALLET
    read -p 'Enter Node Name: ' NODE_NAME
    read -p 'Enter Email: ' NODE_EMAIL
    LOCATION=\$(curl -s ipinfo.io | grep '\"city\"' | cut -d'\"' -f4)
    COUNTRY=\$(curl -s ipinfo.io | grep '\"country\"' | cut -d'\"' -f4)
    NODE_LOCATION=\"\${LOCATION}, \${COUNTRY}\"
    cat > /app/pipe/.env <<EOF
NODE_SOLANA_PUBLIC_KEY=\${WALLET}
NODE_NAME=\${NODE_NAME}
NODE_EMAIL=\${NODE_EMAIL}
NODE_LOCATION=\${NODE_LOCATION}
MEMORY_CACHE_SIZE_MB=512
DISK_CACHE_SIZE_GB=25
DISK_CACHE_PATH=./cache
HTTP_PORT=80
HTTPS_PORT=443
UPNP_ENABLED=false
EOF
    chmod 600 /app/pipe/.env
    echo '✅ .env file created.'
else
    echo '>>> Existing .env found, skipping creation.'
fi

echo '✅ Setup inside container done.'
"

# -------------------- AUTO-RUN SETUP --------------------
echo_green ">> Adding auto-run for pipe-node container..."
docker update --restart unless-stopped pipe-node >/dev/null 2>&1
echo_green "✅ Auto restart on reboot enabled."

echo_green ">> All setup complete!"
echo_yellow "To enter container anytime: sudo docker exec -it pipe-node bash"
echo_yellow "To start node manually: cd /app/pipe && source .env && ./pop"
echo_green "✅ You can now run this inside a screen session for 24/7 uptime!"
