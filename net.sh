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
   echo_red "Please run as root (sudo bash pipe_full_auto_setup.sh)"
   exit 1
fi

# -------------------- SETUP WORKING DIRECTORY --------------------
WORK_DIR="$(pwd)/pipe_docker_work"
CONTAINER_NAME="pipe-debian"

echo_green "📁 Working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# -------------------- INSTALL DOCKER --------------------
echo_green ">> Installing Docker..."
apt update -y >/dev/null 2>&1
apt install -y docker.io >/dev/null 2>&1
systemctl enable --now docker >/dev/null 2>&1
echo_green "✅ Docker installed & running"

# -------------------- REMOVE OLD CONTAINER --------------------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo_yellow "🗑️ Removing existing container..."
    docker rm -f $CONTAINER_NAME >/dev/null 2>&1 || true
fi

# -------------------- CREATE CONTAINER --------------------
echo_green ">> Creating Debian container..."
docker run -dit \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -v "$WORK_DIR":/app \
    -w /app \
    debian:testing bash
echo_green "✅ Container ready (mounted to /app)"

# -------------------- INSTALL DEPENDENCIES INSIDE CONTAINER --------------------
echo_green ">> Installing dependencies inside container..."
docker exec $CONTAINER_NAME bash -c "
set -e
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
apt update -y >/dev/null 2>&1
apt install -y curl unzip ufw screen iputils-ping dnsutils libc6 tmux >/dev/null 2>&1
"

# -------------------- INSTALL PIPE INSIDE DOCKER FOLDER --------------------
echo_green ">> Installing Pipe Node inside /app (same folder)..."
docker exec -it $CONTAINER_NAME bash -c "
set -e
cd /app
mkdir -p pipe/cache
cd pipe

if [[ ! -f './pop' ]]; then
    echo '>>> Downloading Pipe POP binary...'
    curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o pop
    chmod +x pop
fi

if [[ ! -f './.env' ]]; then
    echo '>>> Creating .env file...'
    LOCATION=\$(curl -s ipinfo.io | grep '\"city\"' | cut -d'\"' -f4)
    COUNTRY=\$(curl -s ipinfo.io | grep '\"country\"' | cut -d'\"' -f4)
    NODE_LOCATION=\"\${LOCATION}, \${COUNTRY}\"
    read -p 'Enter Solana Wallet Address: ' WALLET
    read -p 'Enter Node Name: ' NODE_NAME
    read -p 'Enter Email: ' NODE_EMAIL

    cat > .env <<EOF
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
    chmod 600 .env
    echo '✅ .env created'
else
    echo '>>> Using existing .env'
fi

# -------------------- RUN POP IN TMUX SESSION --------------------
if tmux has-session -t pipe 2>/dev/null; then
    echo '⚠️ Tmux session already running, skipping...'
else
    echo '🚀 Starting Pipe Node inside tmux session (background)...'
    tmux new-session -d -s pipe 'cd /app/pipe && source .env && ./pop'
    echo '✅ Pipe Node is now running in tmux session: pipe'
fi
"

# -------------------- DONE --------------------
echo_green "🎉 FULL AUTO SETUP COMPLETE!"
echo_yellow "→ Folder: $WORK_DIR"
echo_yellow "→ Container: $CONTAINER_NAME (auto-restarts on boot)"
echo_yellow "→ Node running inside tmux session named 'pipe'"
echo_yellow "→ Enter container: sudo docker exec -it $CONTAINER_NAME bash"
echo_yellow "→ Attach to tmux: sudo docker exec -it $CONTAINER_NAME tmux attach -t pipe"
echo_yellow "→ Detach from tmux: Ctrl+B then D"
echo_yellow "→ View logs: sudo docker logs -f $CONTAINER_NAME"
