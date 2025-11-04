#!/bin/bash
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
echo_green(){ echo -e "${GREEN}$1${NC}"; }; echo_yellow(){ echo -e "${YELLOW}$1${NC}"; }; echo_red(){ echo -e "${RED}$1${NC}"; }

CONTAINER_NAME="pipe-node-systemd"
WORK_DIR="$(pwd)/pipe_docker_systemd"

echo_green "📁 Working directory: $WORK_DIR"
mkdir -p "$WORK_DIR"

apt update -y >/dev/null 2>&1
apt install -y docker.io >/dev/null 2>&1
systemctl enable --now docker >/dev/null 2>&1

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo_yellow "🗑 Removing old container..."
  docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
fi

echo_green ">> Creating container with full systemd support..."
docker run -dit \
  --name ${CONTAINER_NAME} \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v "$WORK_DIR":/opt/pipe \
  -w /opt/pipe \
  ghcr.io/yeasy/docker-systemd:ubuntu24.04

echo_green "✅ Container ready with systemd."

echo_green ">> Installing dependencies inside container..."
docker exec ${CONTAINER_NAME} bash -c "
set -e
apt update -y && apt install -y curl ufw unzip iputils-ping dnsutils >/dev/null 2>&1
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
"

echo_green ">> Installing Pipe inside container..."
docker exec -it ${CONTAINER_NAME} bash -c "
set -e
mkdir -p /opt/pipe/cache
cd /opt/pipe
if [[ ! -f './pop' ]]; then
  echo '>>> Downloading POP binary...'
  curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o pop
  chmod +x pop
fi

if [[ ! -f './.env' ]]; then
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
  echo '✅ .env created.'
else
  echo 'Using existing .env'
fi

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

echo_green "🎉 Pipe Node running inside systemd-enabled container!"
echo_yellow "👉 To enter container: sudo docker exec -it ${CONTAINER_NAME} bash"
echo_yellow "👉 To view node logs: sudo docker exec -it ${CONTAINER_NAME} journalctl -u pipe -f"
echo_yellow "👉 To restart node: sudo docker exec -it ${CONTAINER_NAME} systemctl restart pipe"
