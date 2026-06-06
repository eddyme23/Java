#!/bin/bash

# ==========================================================
# Hysteria 2 Installer - Hysteria 1 Emulation Mode
# Features: Salamander Obfuscation (No SNI Required)
# ==========================================================

# 1. Root Check
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

clear
echo "=========================================================="
echo "          Hysteria 2 Advanced Installer                   "
echo "=========================================================="
echo ""

# 2. Variable Prompts
read -p "Enter your Connection Password [default: GuruzScript]: " PASSWORD
PASSWORD=${PASSWORD:-GuruzScript}

read -p "Enter your Salamander Obfuscation Password [default: GuruzScript]: " OBFS_PASS
OBFS_PASS=${OBFS_PASS:-GuruzScript}

# Set a dummy SNI for certificate generation (since obfuscation hides it anyway)
SNI_DOMAIN="bing.com"

echo ""
echo "Installing dependencies..."
apt-get update -y > /dev/null 2>&1
apt-get install -y curl wget openssl > /dev/null 2>&1

# 3. Architecture Check & Binary Download
OS="$(uname -s)"
ARCH="$(uname -m)"
BINARY_NAME=""

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64|amd64) BINARY_NAME="hysteria-linux-amd64";;
      aarch64|arm64) BINARY_NAME="hysteria-linux-arm64";;
      *) echo "Unsupported architecture: $ARCH"; exit 1;;
    esac;;
  *) echo "Unsupported OS: $OS"; exit 1;;
esac

echo "Downloading Hysteria 2 core..."
wget -qO /usr/local/bin/hysteria "https://github.com/apernet/hysteria/releases/latest/download/$BINARY_NAME"
chmod +x /usr/local/bin/hysteria

# 4. Certificate Generation
echo "Generating self-signed certificate..."
mkdir -p /etc/hysteria
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key > /dev/null 2>&1
openssl req -new -x509 -days 36500 -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=$SNI_DOMAIN" > /dev/null 2>&1

# 5. Core Configuration File
echo "Writing Hysteria 2 configuration..."
cat > /etc/hysteria/config.yaml <<EOF
listen: :36712

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: "$PASSWORD"

# This block enables the Hysteria 1 emulation (packet scrambling)
obfs:
  type: salamander
  salamander:
    password: "$OBFS_PASS"

bandwidth:
  up: 1 gbps
  down: 1 gbps

ignoreClientBandwidth: true
EOF

# 6. SystemD Service for Hysteria 2
echo "Configuring SystemD service..."
cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria 2 Server
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# 7. Service Initialization
systemctl daemon-reload
systemctl enable hysteria-server.service > /dev/null 2>&1
systemctl restart hysteria-server.service

# 8. Final Output & Share Link
PUBLIC_IP=$(curl -s -4 ipv4.icanhazip.com || hostname -I | awk '{print $1}')

echo ""
echo "=========================================================="
echo "          Installation Complete!                          "
echo "=========================================================="
echo "  Server IP       : $PUBLIC_IP"
echo "  Port            : 36712"
echo "  Auth Password   : $PASSWORD"
echo "  Obfs Password   : $OBFS_PASS"
echo "=========================================================="
echo ""
echo "----------------------------------------------------------"
echo "v2rayN / NekoBox Import URL:"
echo "----------------------------------------------------------"
echo "hysteria2://$PASSWORD@$PUBLIC_IP:36712/?insecure=1&sni=$SNI_DOMAIN&obfs=salamander&obfs-password=$OBFS_PASS#Hys2_Obfuscated"
echo "----------------------------------------------------------"
echo "Copy the URL above and paste it into your client using Ctrl+V."
echo ""
