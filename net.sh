#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
echo_green(){ echo -e "${GREEN}$1${NC}"; }
echo_yellow(){ echo -e "${YELLOW}$1${NC}"; }
echo_red(){ echo -e "${RED}$1${NC}"; }

CONTAINER_NAME="pipe-node-systemd"
WORK_DIR="$(pwd)/pipe_docker_systemd"

# -------------------- SETUP HOST -------------------- ssss
echo_green "📁 Setting up working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"

echo_green ">> Installing Docker if missing..."
apt update -y >/dev/null 2>&1
apt install -y docker.io >/dev/null 2>&1
systemctl enable --now docker >/dev/null 2>&1

# -------------------- CLEAN OLD CONTAINER --------------------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo_yellow "🗑 Removing old container..."
  docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
fi

# -------------------- CREATE SYSTEMD-CAPABLE CONTAINER --------------------
echo_green ">> Creating Ubuntu 24.04 container with systemd..."
docker run -dit \
  --name ${CONTAINER_NAME} \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v "$WORK_DIR":/opt/pipe \
  -w /opt/pipe \
  ubuntu:24.04 /sbin/init

echo_green "✅ Container created successfully."

# -------------------- INSTALL DEPENDENCIES INSIDE --------------------
echo_green ">> Installing system dependencies inside container..."
docker exec ${CONTAINER_NAME} bash -c "
set -e
apt update -y && apt install -y curl ufw unzip iputils-ping dnsutils systemd >/dev/null 2>&1
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
"

# -------------------- INSTALL PIPE INSIDE CONTAINER --------------------
echo_green ">> Setting up Pipe inside container..."
docker exec -it ${CONTAINER_NAME} bash -c "
set -e
mkdir -p /opt/pipe/cache
cd /opt/pipe

if [[ ! -f '/opt/pipe/pop' ]]; then
  echo '>>> Downloading latest Pipe POP binary...'
  curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o /opt/pipe/pop
  chmod +x /opt/pipe/pop
fi

if [[ ! -f '/opt/pipe/.env' ]]; then
  LOCATION=\$(curl -s ipinfo.io | grep '\"city\"' | cut -d'\"' -f4)
  COUNTRY=\$(curl -s ipinfo.io | grep '\"country\"' | cut -d'\"' -f4)
  NODE_LOCATION=\"\${LOCATION}, \${COUNTRY}\"
  read -p 'Enter Solana Wallet Address: ' WALLET
  read -p 'Enter Node Name: ' NODE_NAME
  read -p 'Enter Email: ' NODE_EMAIL

  cat > /opt/pipe/.env <<EOF
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
  chmod 600 /opt/pipe/.env
  echo '✅ .env created.'
else
  echo 'Using existing .env'
fi

# -------------------- CREATE SYSTEMD SERVICE --------------------
cat > /etc/systemd/system/pipe.service <<'EOL'
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
EOL

systemctl daemon-reload
systemctl enable pipe
systemctl start pipe
sleep 3
systemctl status pipe --no-pager
"

echo_green "🎉 Pipe Node installed inside Docker container with systemd."
echo_yellow "👉 To enter container: sudo docker exec -it ${CONTAINER_NAME} bash"
echo_yellow "👉 To check node logs: sudo docker exec -it ${CONTAINER_NAME} journalctl -u pipe -f"
echo_yellow "👉 To restart node: sudo docker exec -it ${CONTAINER_NAME} systemctl restart pipe"
echo_yellow "👉 Host auto-start enabled via Docker restart policy."
