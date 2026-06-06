#!/bin/bash

# Function to print characters with delay
print_with_delay() {
    text="$1"
    delay="$2"
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

# Introduction animation
echo ""
echo ""
print_with_delay "hysteria2-installer by DEATHLINE | @NamelesGhoul" 0.1
echo ""
echo ""

# Check for and install required packages
install_required_packages() {
    REQUIRED_PACKAGES=("curl" "openssl" "socat" "cron")
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! command -v $pkg &> /dev/null; then
            apt-get update > /dev/null 2>&1
            apt-get install -y $pkg > /dev/null 2>&1
        fi
    done
}

# Check if the directory /root/hysteria already exists
if [ -d "/root/hysteria" ]; then
    echo "Hysteria seems to be already installed."
    echo ""
    echo "Choose an option:"
    echo ""
    echo "1) Reinstall"
    echo ""
    echo "2) Uninstall"
    echo ""
    read -p "Enter your choice: " choice
    case $choice in
        1)
            # Reinstall
            rm -rf /root/hysteria
            systemctl stop hysteria
            pkill -f 'hysteria*'
            systemctl disable hysteria > /dev/null 2>&1
            rm /etc/systemd/system/hysteria.service
            ;;
        2)
            # Uninstall
            rm -rf /root/hysteria
            systemctl stop hysteria
            pkill -f 'hysteria'
            systemctl disable hysteria > /dev/null 2>&1
            rm /etc/systemd/system/hysteria.service
            ~/.acme.sh/acme.sh --uninstall > /dev/null 2>&1
            echo "Hysteria uninstalled successfully!"
            echo ""
            exit 0
            ;;
        *)
            echo "Invalid choice."
            exit 1
            ;;
    esac
fi

# Install required packages if not already installed
install_required_packages

# Step 1: Check OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

# Determine binary name
BINARY_NAME=""
case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64) BINARY_NAME="hysteria-linux-amd64";;
      386) BINARY_NAME="hysteria-linux-386";;
      amd64) BINARY_NAME="hysteria-linux-amd64";;
      arm64) BINARY_NAME="hysteria-linux-arm64";;
      mipsle) BINARY_NAME="hysteria-linux-mipsle";;
      s390x) BINARY_NAME="hysteria-linux-s390x";;
      amd64-avx) BINARY_NAME="hysteria-linux-amd64-avx";;
      arm) BINARY_NAME="hysteria-linux-arm";;
      armv5) BINARY_NAME="hysteria-linux-armv5";;
      mipsle-sf) BINARY_NAME="hysteria-linux-mipsle-sf";;
      *) echo "Unsupported architecture"; exit 1;;
    esac;;
  *) echo "Unsupported OS"; exit 1;;
esac

# Step 2: Download the binary
mkdir -p /root/hysteria
cd /root/hysteria
wget -q "https://github.com/apernet/hysteria/releases/latest/download/$BINARY_NAME"
chmod 755 "$BINARY_NAME"

# Step 3: Domain and Certificate Setup
echo ""
echo "--- Domain & SSL Setup ---"
read -p "Enter your registered domain (e.g., vpn.yourdomain.com): " user_domain
[ -z "$user_domain" ] && echo "Domain is required." && exit 1

echo ""
echo "IMPORTANT: Ensure $user_domain has an A record pointing to this VPS IP."
echo "If using a CDN proxy, set the record to 'DNS Only'."
read -p "Press Enter to continue once DNS is configured..."

read -p "Enter an email for Let's Encrypt certificate registration: " le_email
[ -z "$le_email" ] && le_email="admin@$user_domain"

echo "Fetching Let's Encrypt certificates using acme.sh..."
# Install acme.sh quietly
curl -s https://get.acme.sh | sh
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Stop services that might block port 80 for the standalone verification
systemctl stop nginx > /dev/null 2>&1
systemctl stop apache2 > /dev/null 2>&1

# Issue and install the cert
~/.acme.sh/acme.sh --issue -d "$user_domain" --standalone -k ec-256 --force
~/.acme.sh/acme.sh --installcert -d "$user_domain" --fullchainpath /root/hysteria/ca.crt --keypath /root/hysteria/ca.key --ecc

# Fallback to self-signed if acme.sh fails
if [ ! -f "/root/hysteria/ca.crt" ]; then
    echo "Certificate fetch failed. Falling back to self-signed certs for $user_domain..."
    openssl ecparam -genkey -name prime256v1 -out /root/hysteria/ca.key
    openssl req -new -x509 -days 36500 -key /root/hysteria/ca.key -out /root/hysteria/ca.crt -subj "/CN=$user_domain"
fi

# Step 4: Prompt user for input
echo ""
read -p "Enter a port (or press enter for a random port): " port
[ -z "$port" ] && port=$((RANDOM + 10000))

echo ""
read -p "Enter an Auth password (or press enter for a random password): " password
[ -z "$password" ] && password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)

echo ""
read -p "Enter an Obfuscation password (or press enter for random): " obfs_password
[ -z "$obfs_password" ] && obfs_password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 10 | head -n 1)

echo ""
read -p "Enter SNI / Bug Host (Default: $user_domain): " sni_host
[ -z "$sni_host" ] && sni_host="$user_domain"

# Create new config.yaml
config_yaml="listen: :$port
tls:
  cert: /root/hysteria/ca.crt
  key: /root/hysteria/ca.key
auth:
  type: password
  password: $password
obfs:
  type: salamander
  salamander:
    password: $obfs_password
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 60s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false
bandwidth:
  up: 1 gbps
  down: 1 gbps
ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
resolver:
  type: udp
  tcp:
    addr: 8.8.8.8:53
    timeout: 4s
  udp:
    addr: 8.8.4.4:53
    timeout: 4s
  tls:
    addr: 1.1.1.1:853
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false
  https:
    addr: 1.1.1.1:443
    timeout: 10s
    sni: cloudflare-dns.com
    insecure: false"
    
echo "$config_yaml" > config.yaml

# Step 5: Run the binary and check the log
/root/hysteria/$BINARY_NAME server -c /root/hysteria/config.yaml > hysteria.log 2>&1 &

# Step 6: Create a system service
cat > /etc/systemd/system/hysteria.service <<EOL
[Unit]
Description=Hysteria VPN Service
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root/hysteria
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/hysteria/$BINARY_NAME server -c /root/hysteria/config.yaml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable hysteria > /dev/null 2>&1
systemctl start hysteria

# Step 7: Generate and print client config files
# If SNI matches the domain with a valid cert, we can set insecure to false, otherwise true.
insecure_flag="true"
insecure_num="1"
if [ "$sni_host" == "$user_domain" ] && [ -f "/root/hysteria/ca.crt" ]; then
    insecure_flag="false"
    insecure_num="0"
fi

echo ""
echo "v2rayN client config:"
echo ""
v2rayN_config="server: $user_domain:$port
auth: $password
obfs:
  type: salamander
  salamander:
    password: $obfs_password
transport:
  type: udp
tls:
  sni: $sni_host
  insecure: $insecure_flag
bandwidth:
  up: 100 mbps
  down: 100 mbps
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 60s
  keepAlivePeriod: 60s
  disablePathMTUDiscovery: false
fastOpen: true
lazy: true
socks5:
  listen: 127.0.0.1:10808
http:
  listen: 127.0.0.1:10809"
echo ""
echo "$v2rayN_config"
echo ""
echo "NekoBox/NekoRay URL:"
echo ""
nekobox_url="hysteria2://$password@$user_domain:$port/?insecure=$insecure_num&sni=$sni_host&obfs=salamander&obfs-password=$obfs_password"
echo ""
echo "$nekobox_url"
echo ""
