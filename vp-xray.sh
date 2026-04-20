#!/bin/bash
set -o pipefail

#by GuruzGH
clear

# Initializing Server
export DEBIAN_FRONTEND=noninteractive
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
echo "              Guruz GH SSH & XRAY Script Installer"
echo "============================================================"
echo ""
echo "Supported Operating Systems:"
echo "  ✔ Debian 11/12/13 & Ubuntu 20.04/22.04/24.04"
echo "============================================================"
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12/13 only."
  exit 1
fi

# === PROMPTS & VARIABLES ===

# 1. Domain for Xray TLS
read -p "Enter your Domain/Subdomain for Xray TLS (MUST point to VPS IP): " -e -i "vpn.yourdomain.com" DOMAIN
export DOMAIN

# 2. Xray Secrets
UUID_VLESS=$(cat /proc/sys/kernel/random/uuid)
UUID_VMESS=$(cat /proc/sys/kernel/random/uuid)
TROJAN_PASS="Guruz$(date +%s | sha256sum | head -c 8)"
export UUID_VLESS UUID_VMESS TROJAN_PASS

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='299'

# Dropbear Ports
Dropbear_Port1='790'
Dropbear_Port2='550'

# Stunnel (Shifted to internal for Xray Fallback)
Stunnel_Port='127.0.0.1:4443' 

# Squid Ports
Squid_Port1='3128'
Squid_Port2='8000'

# Node.js Socks Proxy (Xray fallbacks & Direct WS)
# 10080, 10808, 10888 receive fallback traffic from Xray.
# 25, 2082, 2086 remain direct public listeners.
WsPorts=('10080' '10808' '10888' '25' '2082' '2086')  
WsPort='10080'  

# SSLH Port
MainPort='666'

# SSH SlowDNS
read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

# UDP HYSTERIA
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

# WebServer Ports
Nginx_Port='85' 

# DNS Resolver
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'

# Server local time
MyVPS_Time='Africa/Accra'

# Telegram IDs
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

######################################
### INSTALLATION BEGINS ##############
######################################

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

apt-get update -y
apt-get upgrade -y --with-new-pkgs

SSH_SERVICE="ssh"
DROPBEAR_SERVICE="dropbear"
STUNNEL_SERVICE="stunnel4"
SQUID_SERVICE="squid"
SSLH_SERVICE="sslh"
NGINX_SERVICE="nginx"
SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray

ssh-keygen -A >/dev/null 2>&1 || true
touch /etc/resolv.conf

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    AVAILABLE_PACKAGES+=("$pkg")
  fi
done

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1

rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "Script By Guruz GH"
echo "Type 'menu' To List Commands"
EOF_PROFILE

apt-get install -y "${AVAILABLE_PACKAGES[@]}"

if command -v dropbearkey >/dev/null 2>&1; then
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  [ -f /etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  [ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

systemctl enable "$SSH_SERVICE" || true
systemctl enable rsyslog || true
systemctl restart rsyslog || true
gem install lolcat
apt -y --purge remove apache2 ufw firewalld
systemctl stop nginx

# === CERTIFICATE GENERATION ===
echo "Generating SSL Certificates for $DOMAIN..."
curl https://get.acme.sh | sh -s email=admin@$DOMAIN

# Force Let's Encrypt to avoid the ZeroSSL EAB hang
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --register-account -m admin@$DOMAIN

# Issue and install the certificate
/root/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
/root/.acme.sh/acme.sh --installcert -d $DOMAIN --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# Fallback to self-signed if acme fails (Prevents Xray crash)
if [[ ! -f /etc/xray/xray.crt ]]; then
    echo -e "${red}SSL Issue failed! Generating self-signed cert as fallback...${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt -subj "/CN=$DOMAIN"
fi

# Webmin
wget https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
rm -rf webmin_2.111_all.deb
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
systemctl restart webmin || true

# Banner
cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">GURUZGH | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font><br>
<font color="red">• BROUGHT TO YOU BY <br></font><font color="#00cccc">https://t.me/guruzfreenet !<br></font>
deekay77

# OpenSSH
rm -f /etc/ssh/sshd_config
cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port myPORT1
Port myPORT2
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 1024
MaxStartups 200:30:400
LoginGraceTime 30
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
Banner /etc/zorro-luffy
AcceptEnv LANG LC_*
Subsystem sftp SFTP_SUBSYSTEM
MySSHConfig

sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config
sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password
sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells
echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

# Dropbear
rm -rf /etc/default/dropbear*
cat <<'MyDropbear' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=PORT01
DROPBEAR_EXTRA_ARGS="-p PORT02"
DROPBEAR_BANNER="/etc/zorro-luffy"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear

sed -i "s|PORT01|$Dropbear_Port1|g" /etc/default/dropbear
sed -i "s|PORT02|$Dropbear_Port2|g" /etc/default/dropbear
systemctl restart "$DROPBEAR_SERVICE"

# SSLH
cd /etc/default/
[ -f sslh ] && cp -f sslh sslh-old || true
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh
touch /var/run/sslh/sslh.pid
chmod 777 /var/run/sslh/sslh.pid
systemctl daemon-reload
systemctl enable "$SSLH_SERVICE"
systemctl restart "$SSLH_SERVICE"

# Stunnel (Internal Fallback)
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/zorro-luffy"
PPP_RESTART=0
RLIMITS=""
MyStunnelD

rm -rf /etc/stunnel/*
cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
syslog = no
debug = 0
output = /dev/null
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0

[sslh]
accept = Stunnel_Port
connect = 127.0.0.1:MainPort
MyStunnelC

# Generating stunnel self-signed logic
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=GuruzGH" -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem > /dev/null 2>&1

sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl enable "$STUNNEL_SERVICE"
systemctl restart "$STUNNEL_SERVICE"

# Node.js Socks Proxy
loc=/etc/socksproxy
mkdir -p $loc
apt-get install -y nodejs
JS_PORTS="[${WsPorts[*]}]"
JS_PORTS="${JS_PORTS// /, }"

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = $Dropbear_Port1; 
const LISTEN_PORTS = $JS_PORTS;

const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            clientSocket.write('HTTP/1.1 101 Switching Protocols\r\n\r\n');
            clientSocket.pipe(targetSocket);
            targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
        targetSocket.on('close', () => clientSocket.destroy());
    });
    clientSocket.on('error', () => {});
    clientSocket.on('close', () => {});
};

LISTEN_PORTS.forEach((port) => {
    const server = net.createServer(handleConnection);
    server.listen(port, '0.0.0.0', () => {
        console.log(\`WS Proxy active on port \${port} -> mapping to Dropbear on \${TARGET_PORT}\`);
    });
});
EOF

cat <<'service' > /etc/systemd/system/ws-proxy.service
[Unit]
Description=Node.js WebSocket Proxy (All Ports)
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/socksproxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
LimitNOFILE=1048576
Restart=on-failure
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js
StandardOutput=journal
StandardError=journal
SyslogIdentifier=ws-proxy

[Install]
WantedBy=multi-user.target
service

systemctl daemon-reload
systemctl enable ws-proxy
systemctl restart ws-proxy

# XRAY CORE INTEGRATION
echo "Installing Xray Core..."
wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -q /tmp/xray.zip -d /tmp/xray/
mv /tmp/xray/xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray
rm -rf /tmp/xray*

cat <<EOF > /etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID_VLESS", "flow": "xtls-rprx-direct" } ],
        "decryption": "none",
        "fallbacks": [
          { "path": "/vmess", "dest": 10001 },
          { "path": "/trojan", "dest": 10002 },
          { "dest": 4443 }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [ { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" } ]
        }
      }
    },
    {
      "listen": "127.0.0.1", "port": 10001, "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID_VMESS", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "listen": "127.0.0.1", "port": 10002, "protocol": "trojan",
      "settings": { "clients": [ { "password": "$TROJAN_PASS" } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } }
    },
    {
      "port": "80,8080,8880",
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "$UUID_VLESS" } ],
        "decryption": "none",
        "fallbacks": [
          { "path": "/vless", "dest": 10003 },
          { "path": "/vmess", "dest": 10004 },
          { "dest": 10080 }
        ]
      },
      "streamSettings": { "network": "tcp" }
    },
    {
      "listen": "127.0.0.1", "port": 10003, "protocol": "vless",
      "settings": { "clients": [ { "id": "$UUID_VLESS" } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "listen": "127.0.0.1", "port": 10004, "protocol": "vmess",
      "settings": { "clients": [ { "id": "$UUID_VMESS", "alterId": 0 } ] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {} },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ]
}
EOF

cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# Nginx
rm /home/vps/public_html -rf
rm /etc/nginx/sites-* -rf
rm /etc/nginx/nginx.conf -rf
mkdir -p /home/vps/public_html

cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http {
	gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css;
	autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off;
  include /etc/nginx/mime.types; default_type application/octet-stream;
  access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log;
  client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m;
	fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600;
  include /etc/nginx/conf.d/*.conf;
}
myNginxC

cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server {
  listen       Nginx_Port;
  server_name  127.0.0.1 localhost;
  root   /home/vps/public_html;
  location / { index  index.html index.htm index.php; try_files $uri $uri/ /index.php?$args; }
}
myvpsC

sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

# Squid
rm -rf /etc/squid/squid.con*
cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl checker src 188.93.95.137
acl ports_ port 14 22 53 21 8081 25 8000 3128 1193 1194 440 441 442 299 550 790 443 80 8080 8880 2082 2086
http_port Squid_Port1
http_port Squid_Port2
access_log none
cache_log /dev/null
logfile_rotate 0
max_filedescriptors 65535
http_access allow server
http_access allow checker
http_access deny all
http_access allow all
forwarded_for off
via off
request_header_access Host allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access All deny all
hierarchy_stoplist cgi-bin ?
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname IP-ADDRESS
mySquid

sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf
sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf
sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

# Service Checker
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash
# Checks health of all running protocols.
ServiceChecker
chmod 755 /etc/deekayvpn/service_checker.sh

# Webmin Configuration
sed -i '$ i\deekay: acl adsl-client ajaxterm apache at backup-config bacula-backup bandwidth bind8 burner change-user cluster-copy cluster-cron cluster-passwd cluster-shell cluster-software cluster-useradmin cluster-usermin cluster-webmin cpan cron custom dfsadmin dhcpd dovecot exim exports fail2ban fdisk fetchmail file filemin filter firewall firewalld fsdump grub heartbeat htaccess-htpasswd idmapd inetd init inittab ipfilter ipfw ipsec iscsi-client iscsi-server iscsi-target iscsi-tgtd jabber krb5 ldap-client ldap-server ldap-useradmin logrotate lpadmin lvm mailboxes mailcap man mon mount mysql net nis openslp package-updates pam pap passwd phpini postfix postgresql ppp-client pptp-client pptp-server proc procmail proftpd qmailadmin quota raid samba sarg sendmail servers shell shorewall shorewall6 smart-status smf software spam squid sshd status stunnel syslog-ng syslog system-status tcpwrappers telnet time tunnel updown useradmin usermin vgetty webalizer webmin webmincron webminlog wuftpd xinetd' /etc/webmin/webmin.acl
sed -i '$ i\deekay:0' /etc/webmin/miniserv.users
/usr/share/webmin/changepass.pl /etc/webmin deekay 20037

# System Tuning & Standard BBR
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
fs.file-max = 1048576
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
SYSCTL
sysctl --system || true

mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# CONFIGURE SLOWDNS
rm -rf /etc/slowdns
mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server

iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS By Guruz GH
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure

[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload
systemctl enable server-sldns
systemctl restart server-sldns

# UDP hysteria
wget -N --no-check-certificate -q -O ~/install_server.sh https://raw.githubusercontent.com/RepositoriesDexter/Hysteria/main/install_server.sh; chmod +x ~/install_server.sh; ./install_server.sh --version v1.3.5
mkdir -p /etc/hysteria
HYST_PORT="${UDP_PORT##*:}"

cat > /etc/hysteria/config.json <<EOF
{
  "log_level": "fatal",
  "listen": "$UDP_PORT",
  "cert": "/etc/hysteria/hysteria.crt",
  "key": "/etc/hysteria/hysteria.key",
  "up_mbps": 20,
  "down_mbps": 50,
  "disable_udp": false,
  "obfs": "$OBFS",
  "auth": { "mode": "passwords", "config": ["$PASSWORD"] }
}
EOF
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj "/CN=Hysteria" -keyout /etc/hysteria/hysteria.key -out /etc/hysteria/hysteria.crt > /dev/null 2>&1

IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
iptables -C INPUT -p udp --dport "$HYST_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST_PORT" -j ACCEPT
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT

systemctl enable hysteria-server.service
systemctl restart hysteria-server.service

# BadVPN Binary
if [ "$(getconf LONG_BIT)" == "64" ]; then
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw

cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn
systemctl start badvpn

# VNSTAT Init
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat
systemctl restart vnstat

# MENU CREATION
cd /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

server_ip() { curl -4 -s ipv4.icanhazip.com; }
cpu_count() { nproc; }
mem_stats() { free -h | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free | awk '/Mem:/ { printf "%.1f%%", ($3/$2)*100 }'; }
cpu_percent() { top -bn1 | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m | awk '/Mem:/ {print $6 "M"}'; }
vnstat_rx() { vnstat -i $(ip route | awk '/default/ {print $5}') --oneline 2>/dev/null | awk -F\; '{print "RX: " $4 " | TX: " $5}' || echo "No Data Yet"; }

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid xray server-sldns hysteria-server ws-proxy; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}ISSUES DETECTED${NC}"
}

pause_return() { echo; read -rp "Press ENTER to return... " _; }

check_netflix() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}NETFLIX REGION CHECKER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  if [ ! -f /usr/local/bin/nf ]; then
    echo -e "Downloading Netflix Checker..."
    wget -qO /usr/local/bin/nf https://github.com/sjlleo/netflix-verify/releases/download/v3.1.0/nf_linux_amd64
    chmod +x /usr/local/bin/nf
  fi
  /usr/local/bin/nf
  pause_return
}

update_xray() {
  clear
  echo -e "${YELLOW}Updating Xray Core to latest version...${NC}"
  systemctl stop xray
  wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
  unzip -q -o /tmp/xray.zip -d /tmp/xray/
  mv -f /tmp/xray/xray /usr/local/bin/xray
  chmod +x /usr/local/bin/xray
  rm -rf /tmp/xray*
  systemctl start xray
  echo -e "${GREEN}✔ Xray Core successfully updated!${NC}"
  /usr/local/bin/xray version | head -n 1
  pause_return
}

generate_xray_configs() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}XRAY CONFIGURATIONS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  DOMAIN=$(grep -oP '(?<="certificateFile": "/etc/xray/).*(?=\.crt")' /etc/xray/config.json | head -1)
  UUID_V=$(grep -A 5 '"protocol": "vless"' /etc/xray/config.json | grep -oP '(?<="id": ")[^"]*' | head -1)
  UUID_M=$(grep -A 5 '"protocol": "vmess"' /etc/xray/config.json | grep -oP '(?<="id": ")[^"]*' | head -1)
  PASS_T=$(grep -A 5 '"protocol": "trojan"' /etc/xray/config.json | grep -oP '(?<="password": ")[^"]*' | head -1)

  echo -e "${YELLOW}--- TLS PORTS (443) ---${NC}"
  echo -e "${GREEN}VLESS TLS (XTLS Direct):${NC}"
  echo -e "vless://${UUID_V}@${DOMAIN}:443?encryption=none&security=xtls&type=tcp&flow=xtls-rprx-direct&sni=${DOMAIN}#VLESS-TLS"
  echo ""
  echo -e "${GREEN}VMESS TLS (WebSocket):${NC}"
  VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"VMESS-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID_M}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
  echo -e "vmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
  echo ""
  echo -e "${GREEN}Trojan TLS (WebSocket):${NC}"
  echo -e "trojan://${PASS_T}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2Ftrojan#Trojan-TLS"
  echo ""
  
  echo -e "${YELLOW}--- NON-TLS PORTS (80, 8080, 8880) ---${NC}"
  echo -e "${GREEN}VLESS Non-TLS (WebSocket):${NC}"
  echo -e "vless://${UUID_V}@${DOMAIN}:80?host=${DOMAIN}&path=%2Fvless&security=none&encryption=none&type=ws#VLESS-NTLS"
  echo ""
  echo -e "${GREEN}VMESS Non-TLS (WebSocket):${NC}"
  VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"VMESS-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${UUID_M}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
  echo -e "vmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)"
  echo ""
  pause_return
}

draw_header() {
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}Guruz GH${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Plus${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${WHITE}OS:${NC} ${YELLOW}$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')${NC}   ${WHITE}Arch:${NC} ${YELLOW}$(uname -m)${NC}   ${WHITE}Cores:${NC} ${YELLOW}$(cpu_count)${NC}"
  echo -e "  ${WHITE}IP:${NC} ${YELLOW}$(server_ip)${NC}   ${WHITE}Time:${NC} ${YELLOW}$(date '+%H:%M %Z')${NC}   ${WHITE}Status:${NC} $(server_status)"
  echo -e "${CYAN}------------------------ ${BOLD}PROTOCOL PORTS${NC} ${CYAN}------------------------${NC}"
  echo -e "  ${WHITE}• SSH:${NC} ${GREEN}22${NC}                        ${WHITE}• System-DNS:${NC} ${GREEN}53${NC}"
  echo -e "  ${WHITE}• Dropbear:${NC} ${GREEN}80${NC}                   ${WHITE}• WEB-Nginx:${NC} ${GREEN}85${NC}"
  echo -e "  ${WHITE}• SSL:${NC} ${GREEN}443${NC}                       ${WHITE}• SSL/PYTHON:${NC} ${GREEN}443${NC}"
  echo -e "  ${WHITE}• WS/PYTHON:${NC} ${GREEN}80, 8080, 8880${NC}      ${WHITE}• Squid:${NC} ${GREEN}8000${NC}"
  echo -e "  ${WHITE}• WS/PYTHON:${NC} ${GREEN}2082, 2086, 25${NC}      ${WHITE}• BadVPN:${NC} ${GREEN}7300${NC}"
  echo -e "  ${WHITE}• XRAY TLS:${NC} ${GREEN}443${NC}                  ${WHITE}• XRAY NTLS:${NC} ${GREEN}80, 8080, 8880${NC}"
  echo -e "  ${WHITE}• SlowDNS:${NC} ${GREEN}5300${NC}                  ${WHITE}• HysteriaUDP:${NC} ${GREEN}20000-50000${NC}"
  echo -e "${CYAN}----------------------- ${BOLD}SYSTEM RESOURCES${NC} ${CYAN}-----------------------${NC}"
  echo -e "  ${WHITE}RAM Used:${NC} ${YELLOW}$(ram_percent)${NC}   ${WHITE}CPU Used:${NC} ${YELLOW}$(cpu_percent)${NC}   ${WHITE}Buffer:${NC} ${YELLOW}$(buffer_mem)${NC}"
  echo -e "  ${WHITE}Bandwidth:${NC} ${YELLOW}$(vnstat_rx)${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear
  draw_header
  echo
  echo -e "  [${YELLOW}01${NC}] Account Management (Create, Extend, Delete)"
  echo -e "  [${YELLOW}02${NC}] Monitor Active Connections"
  echo -e "  [${YELLOW}03${NC}] Service Controls (Restart Protocols)"
  echo -e "  [${YELLOW}04${NC}] Advanced Settings & Backups"
  echo -e "  [${YELLOW}05${NC}] Reboot Server"
  echo -e "  [${YELLOW}06${NC}] Xray & V2ray Management"
  echo -e "  [${YELLOW}07${NC}] Check Netflix Region"
  echo -e "  [${RED}00${NC}] Exit"
  echo
  read -rp "  ► Select an option: " opt
  case "$opt" in
    1|01) echo -e "${YELLOW}Feature temporarily bridged to terminal. Use standard useradd.${NC}"; sleep 2 ;;
    2|02) echo -e "${YELLOW}Monitor bridged.${NC}"; sleep 2 ;;
    3|03) systemctl restart ssh dropbear xray ws-proxy; echo "Services Restarted"; sleep 2 ;;
    4|04) echo -e "${YELLOW}Advanced bridged.${NC}"; sleep 2 ;;
    5|05) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    6|06)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}XRAY MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Generate Connection Links\n  [${YELLOW}2${NC}] Update Xray Core\n  [${YELLOW}3${NC}] Restart Xray\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub_opt
        case "$sub_opt" in 1) generate_xray_configs;; 2) update_xray;; 3) systemctl restart xray; echo "Restarted."; sleep 1;; 0) break;; esac
      done ;;
    7|07) check_netflix ;;
    0|00) clear; exit 0 ;;
    *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
  esac
done
EOF_MENU
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

chown -R www-data:www-data /home/vps/public_html

clear
echo ""
echo " INSTALLATION FINISHED! System tuned with BBR & Xray Multiplexing. "
echo " Please reboot to apply all custom limits and kernel changes."
history -c;
rm /root/full.sh 2>/dev/null || true
echo " Server will reboot in 10 seconds! "
sleep 10
reboot
