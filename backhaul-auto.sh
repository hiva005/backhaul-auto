#!/bin/bash
# Check and install dos2unix if needed
if ! command -v dos2unix >/dev/null 2>&1; then
    echo "[INFO] dos2unix not found. Attempting to install..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt install -y dos2unix
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y dos2unix
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y dos2unix
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy dos2unix --noconfirm
    else
        echo "[ERROR] No supported package manager found. Please install dos2unix manually."
        exit 1
    fi
fi

# Convert the script itself to Unix format
echo "[INFO] Converting script to Unix format (LF)..."
dos2unix "$0"

# Check server country using ip-api
echo "Checking server location..."
COUNTRY=$(curl -s http://ip-api.com/json | jq -r .country)
echo "Detected country: $COUNTRY"

# Create directory and go to it
mkdir -p /root/backhaul && cd /root/backhaul

# Download and extract the executable file
wget https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz
tar -xzf backhaul_linux_amd64.tar.gz
rm backhaul_linux_amd64.tar.gz README.md LICENSE

# File paths
CONFIG_PATH="/root/backhaul/config.toml"
SERVICE_PATH="/etc/systemd/system/backhaul.service"

# If server is in Iran
if [ "$COUNTRY" == "Iran" ]; then
    echo "Setting up Backhaul server in Iran..."
    cat > $CONFIG_PATH <<EOF
[server]
bind_addr = "0.0.0.0:800"
transport = "tcp"
token = "hiva"
keepalive_period = 75  
nodelay = true 
heartbeat = 40 
channel_size = 2048
sniffer = false 
web_port = 2065
sniffer_log = "/root/backhaul/backhaul.json"
log_level = "info"
ports = [
        "443",
        "8080",
        "8880",
]
EOF

# If server is outside Iran
else
    echo -e "\033[31mPlease enter the IP address of the external server\033[0m"
    # Get the server IP from the user
    read -p "Server IP: " SERVER_IP
    cat > $CONFIG_PATH <<EOF
[client]
remote_addr = "$SERVER_IP:800"
transport = "tcp"
token = "hiva"
connection_pool = 8
aggressive_pool = true
keepalive_period = 75
dial_timeout = 10
nodelay = true 
retry_interval = 3
sniffer = false
web_port = 2068
sniffer_log = "/root/backhaul/backhaul.json"
log_level = "info"
EOF
fi

# Create systemd service
cat > $SERVICE_PATH <<EOF
[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul/backhaul -c /root/backhaul/config.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable backhaul.service
systemctl start backhaul.service

echo -e "\033[32mBackhaul setup and service start complete\033[0m"
