#!/bin/bash
# Check and install dos2unix if needed
#!/bin/bash

# --- Color setup ---
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# --- Anti-CRLF fixer ---
if grep -q $'\r' "$0"; then
    echo -e "${YELLOW}[WARNING] Detected Windows line endings (CRLF). Fixing temporarily...${NC}"
    tr -d '\r' < "$0" | bash
    exit $?
else
    echo -e "${GREEN}[OK] Line endings are fine. Continuing execution...${NC}"
fi

# --- Your script continues normally from here ---
echo -e "${GREEN}[INFO] Script is now running normally...${NC}"

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
