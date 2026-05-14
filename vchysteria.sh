#!/bin/bash
set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

clear
echo "============================================================"
echo "      Guruz GH - Standalone UDP Hysteria Installer          "
echo "============================================================"
echo ""

# Get Server IP
IPADDR=$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')

# Variables & Prompts
HYST_PORT="36712"
_default_obfs='GuruzScript'
_default_password='GuruzScript'

read -e -p "Enter your Domain/Subdomain [${IPADDR}]: " -i "${IPADDR}" DOMAIN
DOMAIN="${DOMAIN:-${IPADDR}}"

read -e -p "Enter Hysteria obfuscation string (obfs) [${_default_obfs}]: " -i "${_default_obfs}" OBFS
OBFS="${OBFS:-${_default_obfs}}"

read -e -p "Enter Default Hysteria password [${_default_password}]: " -i "${_default_password}" PASSWORD
PASSWORD="${PASSWORD:-${_default_password}}"

echo ""
echo "Installing dependencies..."
apt-get update -y
apt-get install -y curl jq iptables iptables-persistent netfilter-persistent gnupg2 lsb-release cron

# 1. Install & Configure Cloudflare WARP
echo "Installing Cloudflare WARP..."
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update -y && apt-get install -y cloudflare-warp

echo "Registering WARP and setting to proxy mode..."
warp-cli --accept-tos registration new
warp-cli --accept-tos mode proxy
warp-cli --accept-tos connect

# 2. Install Sing-box
echo "Installing Sing-box..."
bash <(curl -fsSL https://sing-box.app/deb-install.sh)
systemctl disable sing-box 2>/dev/null || true

# 3. Setup Hysteria Directory and Certificates
mkdir -p /etc/hysteria
touch /etc/hysteria/users.txt

echo "Generating Certificates..."
cat << EOF > /etc/hysteria/hysteria.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 40:26:da:91:18:2b:77:9c:85:6a:0c:bb:ca:90:53:fe
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=KobZ
        Validity
            Not Before: Jul 22 22:23:55 2020 GMT
            Not After : Jul 20 22:23:55 2030 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (1024 bit)
                Modulus:
                    00:ce:35:23:d8:5d:9f:b6:9b:cb:6a:89:e1:90:af:
                    42:df:5f:f8:bd:ad:a7:78:9a:ca:20:f0:3d:5b:d6:
                    c9:ef:4c:4a:99:96:c3:38:fd:59:b4:d7:65:ed:d4:
                    a7:fa:ab:03:e2:be:88:2f:ca:fc:90:dd:b0:b7:bc:
                    23:cb:83:ac:36:e2:01:57:69:64:b8:e1:9e:51:f0:
                    a6:9d:13:d9:92:6b:4d:04:a6:10:64:a3:3f:6b:ff:
                    fe:32:ac:91:63:c2:71:24:be:9e:76:4f:87:cc:3a:
                    03:a1:9e:48:3f:11:92:33:3b:19:16:9c:d0:5d:16:
                    ee:c1:42:67:99:47:66:67:67
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: CA:FALSE
            X509v3 Subject Key Identifier: 6B:08:C0:64:10:71:A8:32:7F:0B:FE:1E:98:1F:BD:72:74:0F:C8:66
            X509v3 Authority Key Identifier: keyid:64:49:32:6F:FE:66:62:F1:57:4D:BB:91:A8:5D:BD:26:3E:51:A4:D2
                DirName:/CN=KobZ
                serial:01:A4:01:02:93:12:D9:D6:01:A9:83:DC:03:73:DA:ED:C8:E3:C3:B7
            X509v3 Extended Key Usage: TLS Web Server Authentication
            X509v3 Key Usage: Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         a1:3e:ac:83:0b:e5:5d:ca:36:b7:d0:ab:d0:d9:73:66:d1:62:
         88:ce:3d:47:9e:08:0b:a0:5b:51:13:fc:7e:d7:6e:17:0e:bd:
         f5:d9:a9:d9:06:78:52:88:5a:e5:df:d3:32:22:4a:4b:08:6f:
         b1:22:80:4f:19:d1:5f:9d:b6:5a:17:f7:ad:70:a9:04:00:ff:
         fe:84:aa:e1:cb:0e:74:c0:1a:75:0b:3e:98:90:1d:22:ba:a4:
         7a:26:65:7d:d1:3b:5c:45:a1:77:22:ed:b6:6b:18:a3:c4:ee:
         3e:06:bb:0b:ec:12:ac:16:a5:50:b3:ed:46:43:87:72:fd:75:8c:38
-----BEGIN CERTIFICATE-----
MIICVDCCAb2gAwIBAgIQQCbakRgrd5yFagy7ypBT/jANBgkqhkiG9w0BAQsFADAP
MQ0wCwYDVQQDDARLb2JaMB4XDTIwMDcyMjIyMjM1NVoXDTMwMDcyMDIyMjM1NVow
ETEPMA0GA1UEAwwGc2VydmVyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDO
NSPYXZ+2m8tqieGQr0LfX/i9rad4msog8D1b1snvTEqZlsM4/Vm012Xt1Kf6qwPi
vogvyvyQ3bC3vCPLg6w24gFXaWS44Z5R8KadE9mSa00EphBkoz9r//4yrJFjwnEk
vp52T4fMOgOhnkg/EZIzOxkWnNBdFu7BQmeZR2ZnZwIDAQABo4GuMIGrMAkGA1Ud
EwQCMAAwHQYDVR0OBBYEFGsIwGQQcagyfwv+HpgfvXJ0D8hmMEoGA1UdIwRDMEGA
FGRJMm/+ZmLxV027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAEC
kxLZ1gGpg9wDc9rtyOPDtzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMC
BaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEBCwUAA4GBAKE+rIML5V3K
NrfQq9DZc2bRYojOPUeeCAugW1ET/H7XbhcOvfXZqdkGeFKIWuXf0zIiSksIb7Ei
gE8Z0V+dtloX961wqQQA//6EquHLDnTAGnULPpiQHSK6pHomZX3RO1xFoXci7bZr
GKPE7j4GuwvsEqwWpVCz7UZDh3L9dYw4
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/hysteria/hysteria.key
-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAM41I9hdn7aby2qJ
4ZCvQt9f+L2tp3iayiDwPVvWye9MSpmWwzj9WbTXZe3Up/qrA+K+iC/K/JDdsLe8
I8uDrDbiAVdpZLjhnlHwpp0T2ZJrTQSmEGSjP2v//jKskWPCcSS+nnZPh8w6A6Ge
SD8RkjM7GRac0F0W7sFCZ5lHZmdnAgMBAAECgYAFNrC+UresDUpaWjwaxWOidDG8
0fwu/3Lm3Ewg21BlvX8RXQ94jGdNPDj2h27r1pEVlY2p767tFr3WF2qsRZsACJpI
qO1BaSbmhek6H++Fw3M4Y/YY+JD+t1eEBjJMa+DR5i8Vx3AE8XOdTXmkl/xK4jaB
EmLYA7POyK+xaDCeEQJBAPJadiYd3k9OeOaOMIX+StCs9OIMniRz+090AJZK4CMd
jiOJv0mbRy945D/TkcqoFhhScrke9qhgZbgFj11VbDkCQQDZ0aKBPiZdvDMjx8WE
y7jaltEDINTCxzmjEBZSeqNr14/2PG0X4GkBL6AAOLjEYgXiIvwfpoYE6IIWl3re
ebCfAkAHxPimrixzVGux0HsjwIw7dl//YzIqrwEugeSG7O2Ukpz87KySOoUks3Z1
yV2SJqNWskX1Q1Xa/gQkyyDWeCeZAkAbyDBI+ctc8082hhl8WZunTcs08fARM+X3
FWszc+76J1F2X7iubfIWs6Ndw95VNgd4E2xDATNg1uMYzJNgYvcTAkBoE8o3rKkp
em2n0WtGh6uXI9IC29tTQGr3jtxLckN/l9KsJ4gabbeKNoes74zdena1tRdfGqUG
JQbf7qSE3mg2
-----END PRIVATE KEY-----
EOF

# 4. Generate Sing-box Configuration (AdMob Snipe Routing)
echo "Generating Sing-box Configuration..."
cat > /etc/hysteria/config.json <<EOF
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria",
      "tag": "hy1-inbound",
      "listen": "::",
      "listen_port": $HYST_PORT,
      "up_mbps": 100,
      "down_mbps": 100,
      "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": {
        "enabled": true,
        "certificate_path": "/etc/hysteria/hysteria.crt",
        "key_path": "/etc/hysteria/hysteria.key"
      }
    }
  ],
  "outbounds": [
    {
      "type": "socks",
      "tag": "warp-proxy",
      "server": "127.0.0.1",
      "server_port": 40000
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": "hy1-inbound",
        "domain_suffix": [
          "doubleclick.net",
          "googlesyndication.com",
          "googleadservices.com",
          "admob.com",
          "google-analytics.com",
          "app-measurement.com",
          "adservice.google.com",
          "g.doubleclick.net",
          "google.com",
          "pagead2.googlesyndication.com",
          "tpc.googlesyndication.com",
          "googlevideo.com",
          "gvt1.com",
          "gvt2.com",
          "gvt3.com",
          "ytimg.com",
          "youtube.com",
          "gstatic.com",
          "googleusercontent.com",
          "ggpht.com",
          "play.google.com",
          "firebaseio.com",
          "firebase.googleapis.com",
          "crashlytics.com",
          "fundingchoicesmessages.google.com",
          "imasdk.googleapis.com",
          "googleanalytics.com",
          "analytics.google.com",
          "fcm.googleapis.com",
          "mtalk.google.com",
          "firebaseinstallations.googleapis.com",
          "firebaselogging.googleapis.com",
          "firebaselogging-pa.googleapis.com",
          "firebaseremoteconfig.googleapis.com",
          "googleadapis.com",
          "accounts.google.com",
          "play.googleapis.com",
          "android.apis.google.com",
          "adsense.com",
          "1e100.net"
        ],
        "outbound": "warp-proxy"
      },
      {
        "inbound": "hy1-inbound",
        "outbound": "direct"
      }
    ],
    "auto_detect_interface": true
  }
}
EOF

chmod 755 /etc/hysteria/config.json
chmod 755 /etc/hysteria/hysteria.crt
chmod 755 /etc/hysteria/hysteria.key

# Populate initial user in database
exp_date=$(date -d "+365 days" +"%Y-%m-%d")
echo "$PASSWORD $exp_date" > /etc/hysteria/users.txt

# 5. Create Systemd Service
echo "Creating Hysteria Systemd Service..."
cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Sing-Box Hysteria v1 Core
After=network.target

[Service]
User=root
ExecStart=/usr/bin/sing-box run -c /etc/hysteria/config.json
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# 6. Apply Port Forwarding & NAT Rules
echo "Setting up NAT and IPtables Rules..."
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
iptables -C INPUT -p udp --dport "$HYST_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST_PORT" -j ACCEPT
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT

cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore Hysteria UDP NAT rule
After=network-online.target
Wants=network-online.target
Before=hysteria-server.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

# 7. Create the Command Line Menu (vc)
echo "Installing Custom Menu (vc)..."
cat << 'EOF_MENU' > /usr/local/bin/vc
#!/bin/bash

# --- System Variables (Set during install) ---
MY_DOMAIN="DOMAIN_PLACEHOLDER"
MY_OBFS="OBFS_PLACEHOLDER"
MY_PORT="PORT_PLACEHOLDER"

# --- Styling ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

CONFIG="/etc/hysteria/config.json"
USER_DB="/etc/hysteria/users.txt"
touch "$USER_DB"

# --- Header Functions ---
get_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
get_os() { source /etc/os-release 2>/dev/null; echo "${ID^^} ${VERSION_ID}"; }
get_arch() { uname -m; }
get_cores() { nproc 2>/dev/null || echo "1"; }
get_time() { date '+%H:%M %Z'; }
get_ram() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
get_buffer() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "MB"}'; }
check_status() { systemctl is-active --quiet hysteria-server 2>/dev/null && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}OFFLINE${NC}"; }
pause_return() { echo ""; read -rp "Press ENTER to return to menu... " _; }

# --- Menu Functions ---
add_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREATE HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password/Auth String: " new_pass
    
    if grep -qw "^$new_pass" "$USER_DB" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$CONFIG" >/dev/null; then
        echo -e "\n${RED}Error: User/Password already exists!${NC}"
        pause_return; return
    fi

    read -rp " Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    # Inject into JSON
    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
    echo "$new_pass $exp_date" >> "$USER_DB"
    systemctl restart hysteria-server
    
    echo -e "\n${GREEN}✔ User created successfully!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(get_ip)${NC}"
    echo -e " ${BOLD}Domain:${NC}      ${YELLOW}${MY_DOMAIN}${NC}"
    echo -e " ${BOLD}Port Range:${NC}  ${YELLOW}20000-50000 (-> ${MY_PORT})${NC}"
    echo -e " ${BOLD}User (Pass):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${MY_OBFS}${NC}"
    echo -e " ${BOLD}Expiry Date:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_user() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}DELETE HYSTERIA USER${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    
    if [ ! -s "$USER_DB" ]; then echo -e "No users found."; pause_return; return; fi
    
    # Display users with IDs
    cat -n "$USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to delete: " del_id
    
    # Validate input is a number
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid ID. Please enter a number.${NC}"
        pause_return; return
    fi

    # Extract the password matching that ID
    del_pass=$(sed -n "${del_id}p" "$USER_DB" | awk '{print $1}')
    
    if [ -z "$del_pass" ]; then
        echo -e "${RED}User ID not found.${NC}"
        pause_return; return
    fi

    # Remove from JSON
    jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
    
    # Remove exact line from DB securely
    sed -i "${del_id}d" "$USER_DB"
    
    systemctl restart hysteria-server
    
    echo -e "\n${GREEN}✔ User '$del_pass' deleted successfully!${NC}"
    pause_return
}

extend_user() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTEND HYSTERIA USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    if [ ! -s "$USER_DB" ]; then echo -e "No users found."; pause_return; return; fi

    # Display users with IDs
    cat -n "$USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to extend: " ext_id
    
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid ID. Please enter a number.${NC}"
        pause_return; return
    fi
    
    # Extract password and current expiry
    ext_pass=$(sed -n "${ext_id}p" "$USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$USER_DB" | awk '{print $2}')

    if [ -z "$ext_pass" ]; then
        echo -e "${RED}User ID not found.${NC}"
        pause_return; return
    fi
    
    read -rp " Add Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    
    # Update the specific line in the DB securely
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$USER_DB"
    
    echo -e "\n${GREEN}✔ User '$ext_pass' extended successfully!${NC}"
    echo -e " New Expiry: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_users() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA USERS LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

    if [ ! -s "$USER_DB" ]; then
        echo -e "\n No active users found.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD (AUTH STRING)" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total Active Users: ${YELLOW}$(wc -l < "$USER_DB")${NC}"
    fi
    pause_return
}

edit_speed() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EDIT UP/DOWN SPEEDS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_up=$(jq -r '.inbounds[0].up_mbps' "$CONFIG")
    current_down=$(jq -r '.inbounds[0].down_mbps' "$CONFIG")
    
    echo -e " Current Upload:   ${YELLOW}${current_up} Mbps${NC}"
    echo -e " Current Download: ${YELLOW}${current_down} Mbps${NC}\n"
    
    read -rp " Enter New Upload Speed (Mbps): " new_up
    read -rp " Enter New Download Speed (Mbps): " new_down
    
    if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
        jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
        systemctl restart hysteria-server
        echo -e "\n${GREEN}✔ Speeds updated successfully!${NC}"
    else
        echo -e "\n${RED}Invalid input. Numbers only.${NC}"
    fi
    pause_return
}

uninstall_hysteria() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}UNINSTALL HYSTERIA & WARP${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Are you absolutely sure? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        # 1. Stop and remove Hysteria
        systemctl stop hysteria-server hysteria-nat 2>/dev/null || true
        systemctl disable hysteria-server hysteria-nat 2>/dev/null || true
        rm -rf /etc/hysteria
        rm -f /etc/systemd/system/hysteria-server.service /etc/systemd/system/hysteria-nat.service
        rm -f /etc/cron.d/hysteria-expiry
        
        # 2. Stop, unregister, and purge Cloudflare WARP
        echo -e "\n Removing Cloudflare WARP..."
        warp-cli --accept-tos disconnect 2>/dev/null || true
        warp-cli --accept-tos registration delete 2>/dev/null || true
        apt-get remove --purge -y cloudflare-warp 2>/dev/null || true
        rm -f /etc/apt/sources.list.d/cloudflare-client.list
        
        systemctl daemon-reload
        echo -e "\n${GREEN}✔ Hysteria and WARP completely removed.${NC}"
        rm -f /usr/local/bin/vc
        exit 0
    fi
}

draw_header() {
    local ip=$(get_ip)
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}        >>>>>  🐉  ${YELLOW}${BOLD}Guruz GH Hysteria Menu${NC}${BLUE}  🐉  <<<<<${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${WHITE}IP:${NC} ${YELLOW}${ip}${NC}              ${WHITE}Domain:${NC} ${YELLOW}${MY_DOMAIN}${NC}"
    echo -e "  ${WHITE}OS:${NC} ${YELLOW}$(get_os)${NC}          ${WHITE}Arch:${NC} ${YELLOW}$(get_arch)${NC}   ${WHITE}Cores:${NC} ${YELLOW}$(get_cores)${NC}"
    echo -e "  ${WHITE}Time:${NC} ${YELLOW}$(get_time)${NC}      ${WHITE}Status:${NC} $(check_status)"
    echo -e "  ${WHITE}RAM Used:${NC} ${YELLOW}$(get_ram)${NC}   ${WHITE}Buffer:${NC} ${YELLOW}$(get_buffer)${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

# --- Main Loop ---
while true; do
    clear
    draw_header
    echo -e "  [${YELLOW}1${NC}] Create User"
    echo -e "  [${YELLOW}2${NC}] Delete User"
    echo -e "  [${YELLOW}3${NC}] Extend User"
    echo -e "  [${YELLOW}4${NC}] List All Users"
    echo -e "  [${YELLOW}5${NC}] Edit Up/Down Speeds"
    echo -e "  [${YELLOW}6${NC}] Restart Hysteria Service"
    echo -e "  [${RED}7${NC}] Uninstall Hysteria"
    echo -e "  [${RED}8${NC}] Reboot Server"
    echo -e "  [${YELLOW}0${NC}] Exit\n"
    read -rp "  ► Select an option: " opt

    case "$opt" in
        1) add_user ;;
        2) del_user ;;
        3) extend_user ;;
        4) list_users ;;
        5) edit_speed ;;
        6) systemctl restart hysteria-server; echo -e "${GREEN}✔ Service Restarted!${NC}"; sleep 1 ;;
        7) uninstall_hysteria ;;
        8) read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
        0) clear; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
EOF_MENU

# Inject Variables into Menu
sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/vc
sed -i "s|OBFS_PLACEHOLDER|$OBFS|g" /usr/local/bin/vc
sed -i "s|PORT_PLACEHOLDER|$HYST_PORT|g" /usr/local/bin/vc

chmod +x /usr/local/bin/vc

# 8. Automated Expiry Tracking
echo "Setting up Automated Expiry tracking..."
cat << 'EOF_EXP' > /usr/local/bin/hysteria-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
USER_DB="/etc/hysteria/users.txt"
CONFIG="/etc/hysteria/config.json"

if [ -f "$USER_DB" ]; then
  while read -r user exp; do
    if [[ "$now" > "$exp" ]]; then
      # Remove from JSON
      jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
      # Remove from DB
      sed -i "/^$user /d" "$USER_DB"
    fi
  done < "$USER_DB"
  systemctl restart hysteria-server
fi
EOF_EXP

chmod +x /usr/local/bin/hysteria-exp
echo "0 0 * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry

# Enable and Start Services
echo "Starting Services..."
systemctl daemon-reload
systemctl enable --now hysteria-nat.service
systemctl enable --now hysteria-server.service

# Save rules to persist on reboot
netfilter-persistent save >/dev/null 2>&1 || true

echo ""
echo "============================================================"
echo "              Hysteria Installation Complete!               "
echo "============================================================"
echo "Domain:         $DOMAIN"
echo "Port Range:     20000-50000 (Forwarded to $HYST_PORT)"
echo "Obfuscation:    $OBFS"
echo "Default Pass:   $PASSWORD"
echo "============================================================"
echo "          Type 'vc' from anywhere to access menu!           "
echo "============================================================"
