#!/bin/bash
# ============================================================
# Script: Guruz GH Ultimate Master Build
# Edition: Shared-Port Multiplexing (Xray + SSH + UDP)
# Optimized for: Ubuntu 20.04/22.04/24.04 & Debian 11/12/13
# ============================================================

set -o pipefail
export DEBIAN_FRONTEND=noninteractive
clear

# =========================================================
# OS COMPATIBILITY CHECK
# =========================================================
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  debian:13) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "============================================================"
echo "              Guruz GH SSH Script Installer"
echo "        (With Xray Multiplexed Port Sharing)"
echo "============================================================"
echo ""
echo "Supported Operating Systems:"
echo ""
echo "  ✔ Debian 13              (Supported)"
echo "  ✔ Debian 12              (Recommended)"
echo "  ✔ Debian 11              (Legacy Support)"
echo "  ✔ Ubuntu 24.04           (Supported)"
echo "  ✔ Ubuntu 22.04           (Recommended)"
echo "  ✔ Ubuntu 20.04           (Legacy Support)"
echo ""
echo "============================================================"
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12/13 only."
  echo "Detected: ${ID} ${VERSION_ID}"
  exit 1
fi

if [ "$SUPPORT_LEVEL" = "legacy" ]; then
  echo "Detected ${ID} ${VERSION_ID}."
  echo "This version is allowed, but marked as legacy support."
  echo "Ubuntu 22.04 or Debian 12/13 is recommended."
  sleep 3
fi

# =========================================================
# 1. INITIALIZATION & VARIABLES
# =========================================================
IPADDR=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
MyVPS_Time='Africa/Accra'

# Port Mapping
SSH_Port1='22'
SSH_Port2='299'
Dropbear_Port1='790'
Dropbear_Port2='550'
MainPort='666'           # Internal SSLH Router (Fallback from Xray)
Xray_Internal_WS='10080' # Xray internal WS (VLESS)
Xray_Internal_VMESS='10081' # Xray internal WS (VMESS)
Xray_Trojan_Port='4443'  # Xray internal Trojan
Stunnel_Port='444'       # Moved out of the way of Xray 443
Squid_Port1='3128'
Squid_Port2='8000'
Nginx_Port='85'

# Node.js Socks Proxy Ports
WsPorts=('80' '8080' '8880' '25' '2082' '2086') 

# =========================================================
# INTERACTIVE PROMPTS (SlowDNS & Hysteria)
# =========================================================
read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

UDP_PORT=":36712"
_default_obfs='GuruzScript'
_default_password='GuruzScript'

if [ -t 0 ]; then
  read -e -p "Enter Hysteria obfuscation string (obfs) [${_default_obfs}]: " -i "${_default_obfs}" _input_obfs
  OBFS="${_input_obfs:-${_default_obfs}}"
  read -e -p "Enter Hysteria password [${_default_password}]: " -i "${_default_password}" _input_pass
  PASSWORD="${_input_pass:-${_default_password}}"
else
  OBFS="${OBFS:-${_default_obfs}}"
  PASSWORD="${PASSWORD:-${_default_password}}"
fi
export OBFS PASSWORD

My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

# =========================================================
# 2. DEPENDENCY INSTALLATION
# =========================================================
echo "Preparing system and installing all core dependencies..."
apt-get update -y && apt-get upgrade -y
PACKAGE_LIST=(
    neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar gzip
    iptables iptables-persistent netfilter-persistent bc cron dos2unix whois 
    nginx certbot jq figlet git openssh-server rsyslog lsof procps uuid-runtime nodejs
)
apt-get install -y "${PACKAGE_LIST[@]}"

# =========================================================
# 3. SYSTEM OPTIMIZATION
# =========================================================
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null

# =========================================================
# 4. SSH & DROPBEAR (Internal Targets)
# =========================================================
rm -f /etc/ssh/sshd_config
cat <<EOF > /etc/ssh/sshd_config
Port $SSH_Port1
Port $SSH_Port2
AddressFamily inet
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
Subsystem sftp internal-sftp
EOF
systemctl restart ssh

cat <<EOF > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=$Dropbear_Port1
DROPBEAR_EXTRA_ARGS="-p $Dropbear_Port2"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
systemctl restart dropbear

# =========================================================
# 5. SSLH INTERNAL ROUTER (The Fallback Target)
# =========================================================
cat <<EOF > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:80 --pidfile /var/run/sslh/sslh.pid"
EOF
systemctl restart sslh

# =========================================================
# 6. NODE.JS BOUNCER (Shared Port 80 & Common WS Ports)
# =========================================================
mkdir -p /etc/socksproxy
JS_PORTS="[${WsPorts[*]}]"
JS_PORTS="${JS_PORTS// /, }"

cat <<EOF > /etc/socksproxy/proxy.js
const net = require('net');
const DROPBEAR_PORT = $Dropbear_Port1; 
const XRAY_VLESS_PORT = $Xray_Internal_WS;
const XRAY_VMESS_PORT = $Xray_Internal_VMESS;
const LISTEN_PORTS = $JS_PORTS;

const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const req = data.toString();
        // Path-based routing for Xray vs SSH
        if (req.includes('GET /vless') || req.includes('GET /xray')) {
            const xraySocket = net.connect(XRAY_VLESS_PORT, '127.0.0.1', () => {
                xraySocket.write(data);
                clientSocket.pipe(xraySocket);
                xraySocket.pipe(clientSocket);
            });
            xraySocket.on('error', () => clientSocket.destroy());
        } else if (req.includes('GET /vmess')) {
            const xraySocket = net.connect(XRAY_VMESS_PORT, '127.0.0.1', () => {
                xraySocket.write(data);
                clientSocket.pipe(xraySocket);
                xraySocket.pipe(clientSocket);
            });
            xraySocket.on('error', () => clientSocket.destroy());
        } else {
            const sshSocket = net.connect(DROPBEAR_PORT, '127.0.0.1', () => {
                clientSocket.write('HTTP/1.1 101 Switching Protocols\r\n\r\n');
                clientSocket.pipe(sshSocket);
                sshSocket.pipe(clientSocket);
            });
            sshSocket.on('error', () => clientSocket.destroy());
        }
    });
};

LISTEN_PORTS.forEach(port => net.createServer(handleConnection).listen(port, '0.0.0.0'));
EOF

cat <<EOF > /etc/systemd/system/ws-proxy.service
[Unit]
Description=NodeJS WebSocket Bouncer
[Service]
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now ws-proxy

# =========================================================
# 7. STUNNEL CONFIG (Moved to 444)
# =========================================================
cat <<EOF > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
syslog = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[sslh]
accept = $Stunnel_Port
connect = 127.0.0.1:$MainPort
EOF
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/CN=$IPADDR" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem >/dev/null 2>&1
systemctl restart stunnel4

# =========================================================
# 8. XRAY CORE (Port 443 Bouncer + Trojan + TLS/NTLS)
# =========================================================
mkdir -p /etc/xray /var/log/xray
wget -q -O /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip -q /tmp/xray.zip -d /tmp/xray && mv /tmp/xray/xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray

openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/CN=$IPADDR" \
    -keyout /etc/xray/xray.key -out /etc/xray/xray.crt >/dev/null 2>&1

cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443, "protocol": "vless",
      "settings": { "clients": [], "decryption": "none", "fallbacks": [{ "dest": $MainPort }, { "path": "/trojan", "dest": $Xray_Trojan_Port }] },
      "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "certificates": [{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }] } }
    },
    { "port": $Xray_Trojan_Port, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] } },
    {
      "port": $Xray_Internal_WS, "listen": "127.0.0.1", "protocol": "vless",
      "settings": { "clients": [], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "port": $Xray_Internal_VMESS, "listen": "127.0.0.1", "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Core
[Service]
ExecStart=/usr/local/bin/xray run -c /etc/xray/config.json
Restart=on-failure
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable --now xray

# =========================================================
# 9. SLOWDNS (Port 5300 Public)
# =========================================================
mkdir -p /etc/slowdns
echo "$Serverkey" > /etc/slowdns/server.key
echo "$Serverpub" > /etc/slowdns/server.pub
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/sldns-server

iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

cat <<EOF > /etc/systemd/system/server-sldns.service
[Unit]
Description=SlowDNS on Port 5300
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now server-sldns

# =========================================================
# 10. HYSTERIA UDP & BADVPN
# =========================================================
wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
chmod +x /usr/bin/badvpn-udpgw
cat <<EOF > /etc/systemd/system/badvpn.service
[Unit]
Description=BadVPN UDP Gateway
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now badvpn

wget -N -q -O ~/install_server.sh https://raw.githubusercontent.com/RepositoriesDexter/Hysteria/main/install_server.sh; chmod +x ~/install_server.sh; ./install_server.sh --version v1.3.5
cat <<EOF > /etc/hysteria/config.json
{
  "log_level": "fatal", "listen": "$UDP_PORT",
  "cert": "/etc/hysteria/hysteria.crt", "key": "/etc/hysteria/hysteria.key",
  "up_mbps": 20, "down_mbps": 50,
  "obfs": "$OBFS", "auth": { "mode": "passwords", "config": ["$PASSWORD"] }
}
EOF
iptables -C INPUT -p udp --dport "$HYST_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST_PORT" -j ACCEPT
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :36712
systemctl restart hysteria-server

# =========================================================
# 11. SQUID & NGINX
# =========================================================
cat <<EOF > /etc/squid/squid.conf
acl server dst $IPADDR/32 localhost
acl ports_ port 14 22 53 21 8081 25 8000 3128 1193 1194 440 441 442 299 550 790 443 80 8080 8880 2082 2086
http_port $Squid_Port1
http_port $Squid_Port2
access_log none
cache_log /dev/null
http_access allow all
visible_hostname $IPADDR
EOF
systemctl restart squid

mkdir -p /home/vps/public_html
cat <<EOF > /etc/nginx/conf.d/vps.conf
server { listen $Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; }
EOF
systemctl restart nginx

# =========================================================
# 12. ERROR404 STYLE MASTER MENU 
# =========================================================
cat <<'EOF_MENU' > /usr/local/bin/menu
#!/bin/bash
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

server_ip=$(curl -s ipv4.icanhazip.com || hostname -I | awk '{print $1}')
os_name=$(grep -P '^PRETTY_NAME' /etc/os-release | cut -d '"' -f 2)

cpu_count() { nproc 2>/dev/null || echo "1"; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid nginx server-sldns hysteria-server xray ws-proxy; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}CHECK${NC}"
}

draw_header() {
    clear
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${YELLOW}${BOLD}GURUZ GH - ERROR404 DASHBOARD${NC}"
    echo -e "           ${WHITE}Status: $(server_status) | ${WHITE}IP: ${YELLOW}$server_ip${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}OS:${NC} $os_name"
    echo -e "  ${CYAN}CPU:${NC} $(cpu_percent)   ${CYAN}RAM:${NC} $(ram_percent)   ${CYAN}TIME:${NC} $(date +'%H:%M:%S')"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

pause_return() { echo -e "\n${YELLOW}Press ENTER to return...${NC}"; read -r; }

menu_ssh() {
    while true; do
        draw_header
        echo -e "  [01] Create SSH/WebSocket Account"
        echo -e "  [02] Delete SSH Account"
        echo -e "  [00] Back"
        echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
        read -rp "  Select: " opt
        case $opt in
            1|01) read -rp "  Username: " u; read -rp "  Password: " p; read -rp "  Days: " d;
                  useradd -e $(date -d "+$d days" +%Y-%m-%d) -s /bin/false -M "$u"; echo "$u:$p" | chpasswd
                  echo -e "\n${GREEN}✔ SSH Account Created!${NC}"
                  echo -e "  Ports: 80 (WS), 443 (SSL/TLS), 5300 (DNS)"; pause_return ;;
            2|02) read -rp "  User to delete: " u; userdel -r "$u" 2>/dev/null; echo "Deleted."; pause_return ;;
            0|00) break ;;
        esac
    done
}

menu_xray() {
    while true; do
        draw_header
        echo -e "  [01] Create Xray Multi-Account (Vless/Vmess/Trojan)"
        echo -e "  [02] Delete Xray Account"
        echo -e "  [00] Back"
        echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
        read -rp "  Select: " opt
        case $opt in
            1|01) read -rp "  Username: " user
                  uuid=$(uuidgen)
                  jq '.inbounds[0].settings.clients += [{"id": "'"$uuid"'", "email": "'"$user"'"}]' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq '.inbounds[1].settings.clients += [{"password": "'"$uuid"'", "email": "'"$user"'"}]' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq '.inbounds[2].settings.clients += [{"id": "'"$uuid"'", "email": "'"$user"'"}]' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq '.inbounds[3].settings.clients += [{"id": "'"$uuid"'", "email": "'"$user"'"}]' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  systemctl restart xray
                  
                  v_tls="vless://$uuid@$server_ip:443?security=tls&encryption=none&type=tcp#$user"
                  v_ws="vless://$uuid@$server_ip:80?path=%2Fvless&security=none&encryption=none&type=ws#$user"
                  vm_ws="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$server_ip\",\"port\":\"80\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"\",\"tls\":\"none\"}" | base64 -w 0)"
                  tr_tls="trojan://$uuid@$server_ip:443?security=tls&type=tcp#$user"
                  
                  echo -e "\n${GREEN}✔ Xray Account Ready!${NC}"
                  echo -e "VLESS TLS (443):\n$v_tls\n"
                  echo -e "VLESS WS (80):\n$v_ws\n"
                  echo -e "VMESS WS (80):\n$vm_ws\n"
                  echo -e "Trojan (443):\n$tr_tls\n"
                  echo -e "SlowDNS: Port 5300 | PubKey: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
                  pause_return ;;
            2|02) read -rp "  User to delete: " user
                  jq 'del(.inbounds[0].settings.clients[] | select(.email == "'"$user"'"))' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq 'del(.inbounds[1].settings.clients[] | select(.email == "'"$user"'"))' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq 'del(.inbounds[2].settings.clients[] | select(.email == "'"$user"'"))' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  jq 'del(.inbounds[3].settings.clients[] | select(.email == "'"$user"'"))' /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
                  systemctl restart xray; echo "Deleted."; pause_return ;;
            0|00) break ;;
        esac
    done
}

online_users() {
    draw_header
    echo -e "${CYAN}ACTIVE SESSIONS (SSH & XRAY)${NC}"
    declare -A counts
    while IFS= read -r u; do [[ -n "$u" && "$u" != "root" ]] && ((counts["$u"]++)); done < <(ps -eo args | grep "^sshd: " | awk '{print $2}' | cut -d'@' -f1)
    if [ -f /var/log/xray/access.log ]; then
        while IFS= read -r u; do [[ -n "$u" ]] && ((counts["[X] $u"]++)); done < <(tail -n 100 /var/log/xray/access.log | grep "accepted" | awk '{print $NF}' | sort -u)
    fi
    printf "  %-20s %-10s\n" "USER" "SESSIONS"
    echo -e "  ------------------------------------------"
    for u in "${!counts[@]}"; do printf "  %-20s %-10s\n" "$u" "${counts[$u]}"; done
    pause_return
}

show_ports() {
  clear
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                     ${BOLD}OPEN PORTS${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  ss -lntup 2>/dev/null | egrep ':(22|53|80|85|443|550|25|2082|2086|3128|5300|7300|8000|8080|8880|36712)\b' || true
  pause_return
}

restart_all() {
  systemctl restart ssh dropbear sslh squid nginx server-sldns hysteria-server badvpn xray ws-proxy 2>/dev/null || true
  echo -e "${GREEN}All services restarted.${NC}"
  pause_return
}

protocol_guide() {
  clear
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                    ${BOLD}PROTOCOL GUIDE${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo "SSH: 22"
  echo "Dropbear: 80"
  echo "Xray TLS/Trojan/SSH SSL: 443"
  echo "Xray WS / SSH Node.js WS: 80, 8080, 8880, 2082, 2086, 25"
  echo "SlowDNS: 5300"
  echo "Hysteria UDP: 20000-50000"
  echo "BadVPN: 7300"
  echo "Nginx: 85"
  pause_return
}

while true; do
    draw_header
    echo -e "  [01] SSH & WebSocket Settings"
    echo -e "  [02] Xray (Vless/Vmess/Trojan) Settings"
    echo -e "  [03] Monitoring & Connection Stats"
    echo -e "  [04] Show Open Ports"
    echo -e "  [05] Protocol Guide"
    echo -e "  [06] Restart All VPN Services"
    echo -e "  [00] Exit Script"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    read -rp "  ► Select: " opt
    case $opt in
        1) menu_ssh ;;
        2) menu_xray ;;
        3) online_users ;;
        4) show_ports ;;
        5) protocol_guide ;;
        6) restart_all ;;
        0) clear; exit 0 ;;
    esac
done
EOF_MENU

chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu
netfilter-persistent save >/dev/null 2>&1

# =========================================================================
# FINAL LOGS & PRINTOUTS
# =========================================================================
clear
echo ""
echo " INSTALLATION FINISH! "
echo ""
echo "Server Information: " | tee -a log-install.txt | lolcat
echo "   • Timezone       : $MyVPS_Time "  | tee -a log-install.txt | lolcat
echo "   • IPtables       : [ON]"  | tee -a log-install.txt | lolcat

echo " "| tee -a log-install.txt | lolcat
echo "Automated Features:"| tee -a log-install.txt | lolcat
echo "   • Auto restart server "| tee -a log-install.txt | lolcat
echo "   • Multiplexed Ports (Xray & SSH sharing 80/443)"| tee -a log-install.txt | lolcat

echo " " | tee -a log-install.txt | lolcat
echo "Services & Port Information:" | tee -a log-install.txt | lolcat
echo "   • Dropbear             : [ON] : $Dropbear_Port1 | $Dropbear_Port2 " | tee -a log-install.txt | lolcat
echo "   • Xray TLS / SSH SSL   : [ON] : 443" | tee -a log-install.txt | lolcat
echo "   • Xray WS / SSH Node   : [ON] : 80 | 8080 | 8880 | 2082 | 2086 | 25" | tee -a log-install.txt | lolcat
echo "   • BadVPN               : [ON] : 7300 " | tee -a log-install.txt | lolcat
echo "   • Hysteria             : [ON] : 20000:50000" | tee -a log-install.txt | lolcat

echo "" | tee -a log-install.txt | lolcat
echo "==================== PORTS SUMMARY (Post-Install) ====================" | tee -a log-install.txt
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a log-install.txt
echo "" | tee -a log-install.txt

echo "[1/2] Systemd services (WS proxy)" | tee -a log-install.txt
systemctl is-active ws-proxy >/dev/null 2>&1 && \
    echo "  ws-proxy: active" | tee -a log-install.txt || \
    echo "  ws-proxy: NOT active" | tee -a log-install.txt
echo "" | tee -a log-install.txt

echo "[2/2] NAT/Firewall rules (iptables -t nat) - relevant lines" | tee -a log-install.txt
iptables -t nat -S 2>/dev/null | egrep -n '(REDIRECT|DNAT|--dport 53|5300|36712|20000:50000|--dport 443|--dport 80)' | tee -a log-install.txt || true
echo "" | tee -a log-install.txt

echo ""
figlet GuruzGH Script -c | lolcat
echo "       Installation Complete! System need to reboot to apply all changes! "
history -c;
echo "           Server will secure this server and reboot after 10 seconds! "
sleep 10
reboot
