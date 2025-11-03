#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#     PIPE NETWORK NODE INSTALLER (ENGLISH) - ENHANCED EDITION
#     Fully localized, visually rich, and user-friendly
#     Modified to use Docker with debian:testing for compatibility
# ═══════════════════════════════════════════════════════════════════════════════

tput reset
tput civis

# SYSTEM COLORS
show_orange() { echo -e "\e[38;5;208m$1\e[0m"; }
show_blue()   { echo -e "\e[38;5;33m$1\e[0m"; }
show_green()  { echo -e "\e[38;5;76m$1\e[0m"; }
show_red()    { echo -e "\e[38;5;196m$1\e[0m"; }
show_cyan()   { echo -e "\e[38;5;51m$1\e[0m"; }
show_purple() { echo -e "\e[38;5;129m$1\e[0m"; }
show_gray()   { echo -e "\e[90m$1\e[0m"; }
show_white()  { echo -e "\e[97m$1\e[0m"; }
show_yellow() {
    if [ -t 1 ]; then
        echo -e "\033[1;38;5;226m$1\033[0m"
    else
        echo "$1"
    fi
}
show_pink()   { echo -e "\e[38;5;213m$1\e[0m"; }

# ANIMATED LOADING BAR
loading_bar() {
    local duration=${1:-1}
    local width=30
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    local end=$((SECONDS + duration))

    while [ $SECONDS -lt $end ]; do
        printf "\r%s [%-${width}s]" "$(show_cyan "${chars:i++:1}")" "$(printf '#%.0s' $(seq 1 $(( (SECONDS % width) + 1 )) ))"
        sleep .1
    done
    printf "\r%s [%-${width}s] %s\n" "$(show_green "✓")" "$(printf '█%.0s' $(seq 1 $width))" "$(show_green "Done!")"
}

# SYSTEM FUNCTIONS
exit_script() {
    clear
    echo
    banner "EXITING SYSTEM" "red"
    show_gray  "────────────────────────────────────────────────────────────────────"
    show_orange "All processes terminated safely."
    show_green "Goodbye, Agent. Stay legendary."
    echo
    sleep 1.5
    tput cnorm
    exit 0
}

incorrect_option() {
    echo
    show_red   "Invalid selection!"
    show_orange "Please enter a valid menu number."
    show_gray  "Hint: Use [1], [2], [3], etc."
    echo
    sleep 1.2
}

banner() {
    local text="$1"
    local color="$2"
    local icon=""

    case $color in
        cyan)   icon="SYSTEM" ;;
        green)  icon="SUCCESS" ;;
        red)    icon="ERROR" ;;
        orange) icon="WARNING" ;;
        purple) icon="INIT" ;;
        *)      icon="INFO" ;;
    esac

    echo
    show_gray "═══════════════════════════════════════════════════════════════════════"
    show_"$color" " $icon $text"
    show_gray "═══════════════════════════════════════════════════════════════════════"
    echo
}

process_notification() {
    local message="$1"
    local delay="${2:-1.2}"

    echo
    show_gray  "────────────────────────────────────────────────────────────────────"
    show_purple " $message"
    show_gray  "────────────────────────────────────────────────────────────────────"
    echo
    sleep "$delay"
}

run_commands() {
    local commands="$*"
    local label="${3:-Executing}"

    show_gray "Running: $label..."
    if bash -c "$commands" >/dev/null 2>&1; then
        show_green "Success!"
    else
        show_red "Failed!"
        return 1
    fi
    echo
}

# MENU SYSTEM
menu_header() {
    local service_status=$(systemctl is-active pipe 2>/dev/null || echo "inactive")
    local node_status="OFFLINE"

    if [ "$service_status" = "active" ]; then
        if docker ps | grep -q debian:testing; then
            node_status="ACTIVE"
        else
            node_status="NOT RUNNING"
        fi
    fi

    clear
    show_gray  "═══════════════════════════════════════════════════════════════════════"
    show_cyan  "     PIPE NETWORK NODE - MAINNET v1.0.0 (Docker Edition)"
    show_gray  "═══════════════════════════════════════════════════════════════════════"
    echo
    show_orange "Agent: $(whoami)     $(date +"%H:%M:%S")     $(date +"%Y-%m-%d")"
    show_green  "Service: ${service_status^^}"
    show_blue   "Node Status: $node_status"
    echo
}

menu_item() {
    local num="$1"
    local icon="$2"
    local title="$3"
    local desc="$4"
    printf "  $(show_cyan '[%s]') %-4s %-22s %s %s\n" "$num" "$icon" "$title" "$(show_gray '—')" "$desc"
}

print_logo() {
    clear
    tput civis

    local logo_lines=(
        " .______    __  .______    _______ "
        " |   _  \  |  | |   _  \  |   ____| "
        " |  |_)  | |  | |  |_)  | |  |__ "
        " |   ___/  |  | |   ___/  |   __| "
        " |  |      |  | |  |      |  |____ "
        " | _|      |__| | _|      |_______| "
    )

    local init_msgs=(
        "Initializing secure module..."
        "Establishing quantum-encrypted tunnel..."
        "Loading decentralized node config..."
        "Syncing with Pipe Mainnet..."
        "Validating system integrity..."
        "Terminal access: GRANTED"
    )

    echo
    show_cyan "INITIALIZING MODULE: "
    show_purple "PIPE NETWORK MAINNET"
    show_gray "────────────────────────────────────────────────────────────────────"
    echo
    sleep 0.6

    show_gray "Loading system: "
    loading_bar 1.5
    echo

    for msg in "${init_msgs[@]}"; do
        show_gray "   $msg"
        sleep 0.2
    done
    echo
    sleep 0.6

    for line in "${logo_lines[@]}"; do
        show_cyan "$line"
        sleep 0.1
    done

    echo
    show_green "SYSTEM STATUS: ONLINE & SECURE"
    show_orange ">> ACCESS GRANTED. WELCOME TO PIPE NETWORK."
    show_gray "[v1.0.0 | Secure Session | $(date +'%Y')]"
    echo

    echo -ne "$(show_white 'Awaiting command')"
    for i in {1..3}; do
        echo -ne "."
        sleep 0.5
    done
    echo -e "\n"
    sleep 0.7
    tput cnorm
}

# NODE CHECKS
is_pipe_installed() {
    [[ -d /opt/pipe ]] && [[ -f /opt/pipe/pop ]] && [[ -f /opt/pipe/.env ]]
}

is_node_running() {
    systemctl is-active --quiet pipe
}

# REQUIREMENTS
show_requirements() {
    process_notification "SYSTEM REQUIREMENTS CHECK"

    show_orange "Recommended Hardware & Software:"
    echo
    show_white "   OS: Ubuntu 24.04+ or Debian 11+"
    show_white "   CPU: 2 vCPU (minimum)"
    show_white "   RAM: 4 GB (8 GB recommended)"
    show_white "   Storage: 20 GB SSD (NVMe preferred)"
    show_white "   Network: 100 Mbps+ stable connection"
    show_white "   Ports: 80 & 443 (must be OPEN)"
    show_white "   Docker: Required for compatibility"
    echo
    show_pink "   Solana Wallet: 44-character address required"
    echo
}

# INSTALLATION STEPS
update_system() {
    process_notification "UPDATING SYSTEM PACKAGES"
    run_commands "sudo apt update && sudo apt upgrade -y" "apt update/upgrade"
    show_green "System is now up to date!"
}

install_packages() {
    process_notification "INSTALLING DEPENDENCIES"

    PACKAGES=(
        curl git jq lz4 build-essential unzip make gcc ncdu cmake clang
        pkg-config libssl-dev libzmq3-dev libczmq-dev python3-pip protobuf-compiler
        dos2unix screen docker.io
    )

    for pkg in "${PACKAGES[@]}"; do
        show_gray "   Installing $pkg..."
        if run_commands "sudo apt install -y $pkg" "$pkg"; then
            show_green "   $pkg installed"
        else
            show_red "   Failed: $pkg"
        fi
        sleep 0.3
    done

    # Enable and start Docker
    run_commands "sudo systemctl enable --now docker" "Enabling Docker"
}

download_pipe_binary() {
    process_notification "DOWNLOADING PIPE BINARY"

    run_commands "sudo mkdir -p /opt/pipe" "Creating install directory"
    run_commands "sudo curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o /opt/pipe/pop" "Downloading pop binary"
    run_commands "sudo chmod +x /opt/pipe/pop" "Making executable"

    show_green "Binary ready at /opt/pipe/pop"
}

setup_solana_wallet() {
    process_notification "SOLANA WALLET SETUP"

    while true; do
        read -p "$(show_orange 'Enter your 44-character Solana wallet address: ')" solana_address
        if [[ "$solana_address" =~ ^[A-Za-z0-9]{44}$ ]]; then
            export NODE_SOLANA_PUBLIC_KEY="$solana_address"
            show_green "Wallet linked: $solana_address"
            break
        else
            show_red "Invalid! Must be exactly 44 alphanumeric characters."
        fi
    done
}

setup_node_config() {
    process_notification "CONFIGURING NODE"

    read -p "$(show_orange 'Node name: ')" node_name
    read -p "$(show_orange 'Operator email: ')" node_email
    read -p "$(show_orange 'Node location (e.g. NYC, VPS-EU): ')" node_location

    sudo tee /opt/pipe/.env > /dev/null <<EOF
# Earnings Wallet
NODE_SOLANA_PUBLIC_KEY=$NODE_SOLANA_PUBLIC_KEY

# Node Identity
NODE_NAME=$node_name
NODE_EMAIL="$node_email"
NODE_LOCATION="$node_location"

# Cache
MEMORY_CACHE_SIZE_MB=512
DISK_CACHE_SIZE_GB=100
DISK_CACHE_PATH=./cache

# Ports
HTTP_PORT=80
HTTPS_PORT=443

# Auto port forward (disable on VPS)
UPNP_ENABLED=false
EOF

    show_green "Configuration saved to /opt/pipe/.env"
}

create_systemd_service() {
    process_notification "CREATING SYSTEMD SERVICE"

    sudo tee /etc/systemd/system/pipe.service > /dev/null <<EOF
[Unit]
Description=Pipe Network POP Node (Docker)
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
WorkingDirectory=/opt/pipe
ExecStart=/usr/bin/docker run --network host -v /opt/pipe:/app -w /app debian:testing bash -c 'apt update && apt install -y curl iputils-ping dnsutils && echo "nameserver 8.8.8.8" > /etc/resolv.conf && source /app/.env && /app/pop'
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    run_commands "sudo systemctl daemon-reload" "Reloading systemd"
    run_commands "sudo systemctl enable pipe" "Enabling auto-start"

    show_green "Service 'pipe' created and enabled"
}

start_node() {
    process_notification "LAUNCHING NODE"

    if is_node_running; then
        show_orange "Node already running!"
        return
    fi

    run_commands "sudo systemctl start pipe" "Starting service"
    sleep 4

    if is_node_running; then
        show_green "NODE IS LIVE & SYNCING!"
    else
        show_red "Failed to start node. Check logs."
    fi
}

# MANAGEMENT FUNCTIONS
stop_node() {
    process_notification "STOPPING NODE"
    run_commands "sudo systemctl stop pipe" "Stopping"
    show_green "Node stopped."
}

restart_node() {
    process_notification "RESTARTING NODE"
    run_commands "sudo systemctl restart pipe" "Restarting"
    sleep 3
    is_node_running && show_green "Restarted successfully!" || show_red "Restart failed."
}

view_logs() {
    if is_node_running; then
        process_notification "LIVE LOGS (Press Ctrl+C to exit)"
        show_gray "═══════════════════════════════════════════════════════════════════════"
        sudo journalctl -u pipe -f
    else
        show_red "Node is not running."
    fi
}

show_node_status() { 
    if [ -d /opt/pipe ]; then
        docker run --rm --network host -v /opt/pipe:/app -w /app debian:testing /app/pop status
    else
        show_red "Node not installed."
    fi
}
show_earnings()   { 
    if [ -d /opt/pipe ]; then
        docker run --rm --network host -v /opt/pipe:/app -w /app debian:testing /app/pop earnings
    else
        show_red "Node not installed."
    fi
}

health_check() {
    if is_node_running; then
        process_notification "HEALTH CHECK"
        local result=$(curl -s http://localhost:8081/health)
        [[ $result == "OK" ]] && show_green "HEALTHY" || show_orange "Unhealthy or unreachable"
    else
        show_red "Node offline."
    fi
}

show_solana_address() {
    if [[ -f /opt/pipe/.env ]]; then
        local addr=$(grep "^NODE_SOLANA_PUBLIC_KEY=" /opt/pipe/.env | cut -d'=' -f2)
        show_green "Solana Wallet:"
        show_cyan "   $addr"
    else
        show_red "Config not found."
    fi
}

change_solana_address() {
    process_notification "CHANGE WALLET ADDRESS"
    if is_node_running; then
        show_orange "Stop the node first!"
        return 1
    fi
    setup_solana_wallet
    sudo sed -i "s|NODE_SOLANA_PUBLIC_KEY=.*|NODE_SOLANA_PUBLIC_KEY=$NODE_SOLANA_PUBLIC_KEY|" /opt/pipe/.env
    show_green "Wallet updated!"
}

show_help_commands() {
    process_notification "HELP & COMMANDS"

    show_white "Systemd Commands:"
    show_cyan "   sudo systemctl status pipe      # Check status"
    show_cyan "   sudo systemctl start/stop/restart pipe"
    show_cyan "   sudo journalctl -u pipe -f      # Live logs"

    show_white "Pipe Commands (via Docker):"
    show_cyan "   docker run --rm --network host -v /opt/pipe:/app -w /app debian:testing /app/pop status"
    show_cyan "   docker run --rm --network host -v /opt/pipe:/app -w /app debian:testing /app/pop earnings"
    show_cyan "   curl http://localhost:8081/health"

    show_white "Files:"
    show_cyan "   /opt/pipe/.env     # Config"
    show_cyan "   /opt/pipe/cache/   # Data"
}

remove_pipe() {
    process_notification "UNINSTALL NODE"

    read -p "$(show_orange 'Confirm removal? This cannot be undone! [y/N]: ')" confirm
    [[ ! $confirm =~ ^[Yy]$ ]] && { show_orange "Cancelled."; return; }

    run_commands "sudo systemctl stop pipe && sudo systemctl disable pipe" "Stopping service"
    run_commands "sudo rm -f /etc/systemd/system/pipe.service" "Removing service"
    run_commands "sudo systemctl daemon-reload" "Reloading"
    run_commands "sudo rm -rf /opt/pipe" "Deleting files"

    show_green "Pipe Network Node fully removed."
}

# MAIN INSTALLATION
main_installation() {
    if is_pipe_installed; then
        show_orange "Node already installed!"
        read -p "$(show_cyan 'Press Enter to return...')"
        return
    fi

    show_requirements
    read -p "$(show_cyan 'Proceed with installation? [y/N]: ')" go
    [[ ! $go =~ ^[Yy]$ ]] && { show_orange "Installation cancelled."; return; }

    banner "STARTING INSTALLATION" "purple"

    update_system
    install_packages
    download_pipe_binary
    setup_solana_wallet
    setup_node_config
    create_systemd_service
    start_node

    banner "INSTALLATION COMPLETE" "green"
    show_orange "Next Steps:"
    show_white "   • Allow ports 80 & 443 in firewall"
    show_white "   • Monitor earnings with menu option"
    show_white "   • Join Pipe Network Discord for updates"

    read -p "$(show_cyan 'Press Enter to continue...')"
}

# MANAGEMENT MENU
show_management_menu() {
    while true; do
        menu_header
        menu_item 1 "Logs"           "View real-time logs"
        menu_item 2 "Restart"        "Restart node"
        menu_item 3 "Stop"           "Stop node"
        menu_item 4 "Start"          "Start node"
        menu_item 5 "Status"         "Check node status"
        menu_item 6 "Earnings"       "View earnings"
        menu_item 7 "Health"         "Run health check"
        menu_item 8 "Wallet"         "Show Solana address"
        menu_item 9 "Change Wallet"  "Update wallet"
        menu_item 10 "Help"          "Show commands"
        menu_item 0 "Back"           "Return to main menu"
        echo
        read -p "$(show_gray 'Choose an option ➤ ')" choice

        case $choice in
            1) view_logs ;;
            2) restart_node ;;
            3) stop_node ;;
            4) start_node ;;
            5) show_node_status ;;
            6) show_earnings ;;
            7) health_check ;;
            8) show_solana_address ;;
            9) change_solana_address ;;
            10) show_help_commands ;;
            0) return ;;
            *) incorrect_option ;;
        esac

        [[ $choice != "0" ]] && { echo; show_yellow "Press Enter to continue..."; read -p ""; }
    done
}

# MAIN MENU
print_logo
while true; do
    menu_header
    menu_item 1 "Install"     "Install Pipe Node"
    menu_item 2 "Manage"      "Node management"
    menu_item 3 "Remove"      "Uninstall node"
    menu_item 4 "Exit"        "Exit script"
    echo
    read -p "$(show_gray 'Select option ➤ ')" option

    case $option in
        1) main_installation ;;
        2) is_pipe_installed && show_management_menu || { show_red "Node not installed!"; read -p "$(show_cyan 'Press Enter...')"; } ;;
        3) is_pipe_installed && remove_pipe || { show_red "Nothing to remove."; read -p "$(show_cyan 'Press Enter...')"; }; read -p "$(show_cyan 'Press Enter...')" ;;
        4) exit_script ;;
        *) incorrect_option ;;
    esac
done
