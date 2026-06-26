#!/bin/bash
set -o pipefail

#by GodTech
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
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "============================================================"
echo "              GodTech SSH Script Installer"
echo "                (SSH & WebSockets Only)"
echo "============================================================"
echo ""
echo "Supported Operating Systems:"
echo "  ✔ Debian 12 / 11"
echo "  ✔ Ubuntu 24.04 / 22.04 / 20.04"
echo "============================================================"
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12 only."
  echo "Detected: ${ID} ${VERSION_ID}"
  exit 1
fi

#Script Variables
read -p "Enter your Domain/Subdomain (or press enter for IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

# Ports Configuration
SSH_Port1='22'
SSH_Port2='299'
Dropbear_Port1='790'
Dropbear_Port2='550'
Stunnel_Port='443'
Stunnel_Port_Num='443' 
Squid_Port1='3128'
Squid_Port2='8000'
WsPorts=('80' '8080' '8880' '2082' '2086')  
WsPort='80'  
MainPort='666' 
Nginx_Port='85' 
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'
MyVPS_Time='Africa/Accra'

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

red='\e[1;31m'; green='\e[0;32m'; NC='\e[0m'

apt-get update -y && apt-get upgrade -y --with-new-pkgs

systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

SSH_SERVICE="ssh"; DROPBEAR_SERVICE="dropbear"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar zip gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps iproute2 nodejs
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then AVAILABLE_PACKAGES+=("$pkg"); fi
done

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "Script By GodTech"
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

# === HARDCODED CERTIFICATE FOR STUNNEL ===
echo "Applying default hardcoded SSL Certificate for Stunnel..."
cat <<'EOF_KEY' > /etc/stunnel/stunnel.key
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQClmgCdm7RB2VWK
wfH8HO/T9bxEddWDsB3fJKpM/tiVMt4s/WMdGJtFdRlxzUb03u+HT6t00sLlZ78g
ngjxLpJGFpHAGdVf9vACBtrxv5qcrG5gd8k7MJ+FtMTcjeQm8kVRyIW7cOWxlpGY
6jringYZ6NcRTrh/OlxIHKdsLI9ddcekbYGyZVTm1wd22HVG+07PH/AeyY78O2+Z
tbjxGTFRSYt3jUaFeUmWNtxqWnR4MPmC+6iKvUKisV27P89g8v8CiZynAAWRJ0+A
qp+PWxwHi/iJ501WdLspeo8VkXIb3PivyIKC356m+yuuibD2uqwLZ2//afup84Qu
pRtgW/PbAgMBAAECggEAVo/efIQUQEtrlIF2jRNPJZuQ0rRJbHGV27tdrauU6MBT
NG8q7N2c5DymlT75NSyHRlKVzBYTPDjzxgf1oqR2X16Sxzh5uZTpthWBQtal6fmU
JKbYsDDlYc2xDZy5wsXnCC3qAaWs2xxadPUS3Lw/cjGsoeZlOFP4QtV/imLseaws
7r4KZE7SVO8dF8Xtcy304Bd7UsKClnbCrGsABUF/rqA8g34o7yrpo9XqcwbF5ihQ
TbnB0Ns8Bz30pjgGjJZTdTL3eskP9qMJWo/JM76kSaJWReoXTws4DlQHxO29z3eK
zKdxieXaBGMwFnv23JvXKJ5eAnxzqsL6a+SuNPPN4QKBgQDQhisSDdjUJWy0DLnJ
/HjtsnQyfl0efOqAlUEir8r5IdzDTtAEcW6GwPj1rIOm79ZeyysT1pGN6eulzS1i
6lz6/c5uHA9Z+7LT48ZaQjmKF06ItdfHI9ytoXaaQPMqW7NnyOFxCcTHBabmwQ+E
QZDFkM6vVXL37Sz4JyxuIwCNMQKBgQDLThgKi+L3ps7y1dWayj+Z0tutK2JGDww7
6Ze6lD5gmRAURd0crIF8IEQMpvKlxQwkhqR4vEsdkiFFJQAaD+qZ9XQOkWSGXvKP
A/yzk0Xu3qL29ZqX+3CYVjkDbtVOLQC9TBG60IFZW79K/Zp6PhHkO8w6l+CBR+yR
X4+8x1ReywKBgQCfSg52wSski94pABugh4OdGBgZRlw94PCF/v390En92/c3Hupa
qofi2mCT0w/Sox2f1hV3Fw6jWNDRHBYSnLMgbGeXx0mW1GX75OBtrG8l5L3yQu6t
SeDWpiPim8DlV52Jp3NHlU3DNrcTSOFgh3Fe6kpot56Wc5BJlCsliwlt0QKBgEol
u0LtbePgpI2QS41ewf96FcB8mCTxDAc11K6prm5QpLqgGFqC197LbcYnhUvMJ/eS
W53lHog0aYnsSrM2pttr194QTNds/Y4HaDyeM91AubLUNIPFonUMzVJhM86FP0XK
3pSBwwsyGPxirdpzlNbmsD+WcLz13GPQtH2nPTAtAoGAVloDEEjfj5gnZzEWTK5k
4oYWGlwySfcfbt8EnkY+B77UVeZxWnxpVC9PhsPNI1MTNET+CRqxNZzxWo3jVuz1
HtKSizJpaYQ6iarP4EvUdFxHBzjHX6WLahTgUq90YNaxQbXz51ARpid8sFbz1f37
jgjgxgxbitApzno0E2Pq/Kg=
-----END PRIVATE KEY-----
EOF_KEY

cat <<'EOF_CRT' > /etc/stunnel/stunnel.crt
-----BEGIN CERTIFICATE-----
MIIDRTCCAi2gAwIBAgIUOvs3vdjcBtCLww52CggSlAKafDkwDQYJKoZIhvcNAQEL
BQAwMjEQMA4GA1UEAwwHS29ielZQTjERMA8GA1UECgwIS29iZUtvYnoxCzAJBgNV
BAYTAlBIMB4XDTIxMDcwNzA1MzQwN1oXDTMxMDcwNTA1MzQwN1owMjEQMA4GA1UE
AwwHS29ielZQTjERMA8GA1UECgwIS29iZUtvYnoxCzAJBgNVBAYTAlBIMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZoAnZu0QdlVisHx/Bzv0/W8RHXV
g7Ad3ySqTP7YlTLeLP1jHRibRXUZcc1G9N7vh0+rdNLC5We/IJ4I8S6SRhaRwBnV
X/bwAgba8b+anKxuYHfJOzCfhbTE3I3kJvJFUciFu3DlsZaRmOo64p4GGejXEU64
fzpcSBynbCyPXXXHpG2BsmVU5tcHdth1RvtOzx/wHsmO/DtvmbW48RkxUUmLd41G
hXlJljbcalp0eDD5gvuoir1CorFduz/PYPL/AomcpwAFkSdPgKqfj1scB4v4iedN
VnS7KXqPFZFyG9z4r8iCgt+epvsrromw9rqsC2dv/2n7qfOELqUbYFvz2wIDAQAB
o1MwUTAdBgNVHQ4EFgQUcKFL6tckon2uS3xGrpe1Zpa68VEwHwYDVR0jBBgwFoAU
cKFL6tckon2uS3xGrpe1Zpa68VEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0B
AQsFAAOCAQEAYQP0S67eoJWpAMavayS7NjK+6KMJtlmL8eot/3RKPLleOjEuCdLY
QvrP0Tl3M5gGt+I6WO7r+HKT2PuCN8BshIob8OGAEkuQ/YKEg9QyvmSm2XbPVBaG
RRFjvxFyeL4gtDlqb9hea62tep7+gCkeiccyp8+lmnS32rRtFa7PovmK5pUjkDOr
dpvCQlKoCRjZ/+OfUaanzYQSDrxdTSN8RtJhCZtd45QbxEXzHTEaICXLuXL6cmv7
tMuhgUoefS17gv1jqj/C9+6ogMVa+U7QqOvL5A7hbevHdF/k/TMn+qx4UdhrbL5Q
enL3UGT+BhRAPiA1I5CcG29RqjCzQoaCNg==
-----END CERTIFICATE-----
EOF_CRT

cat /etc/stunnel/stunnel.key /etc/stunnel/stunnel.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem; chown root:root /etc/stunnel/stunnel.pem

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
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
LogLevel QUIET
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
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

# Dropbear
rm -rf /etc/default/dropbear*
cat <<'MyDropbear' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=PORT01
DROPBEAR_EXTRA_ARGS="-p PORT02"
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
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl daemon-reload; systemctl enable "$SSLH_SERVICE"; systemctl restart "$SSLH_SERVICE"
cd

# Stunnel
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER=""
PPP_RESTART=0
RLIMITS=""
MyStunnelD

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

sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl enable "$STUNNEL_SERVICE"; systemctl restart "$STUNNEL_SERVICE"

# Node.js Socks Proxy (Isolated Multi-Process)
loc=/etc/socksproxy; mkdir -p $loc

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });

const TARGET_HOST = '127.0.0.1'; 
const TARGET_PORT = $Dropbear_Port1;
const LISTEN_PORT = parseInt(process.argv[2]);
if (!LISTEN_PORT) { process.exit(1); }

const handleConnection = (clientSocket) => {
    let targetSocket = null;
    let responseSent = false;
    let sshBridged = false;
    let buffer = '';

    const onClientData = (data) => {
        if (sshBridged) return; 
        buffer += data.toString('utf8');

        if (!responseSent && buffer.length > 5) {
            responseSent = true;
            const isConnect = buffer.toUpperCase().startsWith('CONNECT');
            if (isConnect) {
                clientSocket.write('HTTP/1.1 200 OK\r\n\r\n');
            } else {
                clientSocket.write(
                    'HTTP/1.1 101 Switching Protocols\r\n' +
                    'Upgrade: websocket\r\n' +
                    'Connection: Upgrade\r\n\r\n'
                );
            }
        }

        const sshIndex = buffer.indexOf('SSH-');
        if (sshIndex !== -1) {
            sshBridged = true;
            clientSocket.removeListener('data', onClientData);
            targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
                const cleanSshData = buffer.substring(sshIndex);
                targetSocket.write(Buffer.from(cleanSshData, 'utf8'));
                clientSocket.pipe(targetSocket);
                targetSocket.pipe(clientSocket);
            });
            targetSocket.on('error', () => clientSocket.destroy());
            targetSocket.on('close', () => clientSocket.destroy());
        }
    };
    clientSocket.on('data', onClientData);
    clientSocket.on('error', () => {});
    clientSocket.on('close', () => {
        if (targetSocket) targetSocket.destroy();
    });
};

const server = net.createServer(handleConnection);
server.listen(LISTEN_PORT, '0.0.0.0', () => { 
    console.log(\`WS Proxy active on isolated port \${LISTEN_PORT}\`); 
});
EOF

cat <<'service' > /etc/systemd/system/ws-proxy@.service
[Unit]
Description=Node.js WebSocket Proxy on port %i
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/socksproxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
LimitNOFILE=1048576
Restart=always
RestartSec=1
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js %i
SyslogIdentifier=ws-proxy-%i
[Install]
WantedBy=multi-user.target
service

systemctl daemon-reload
for port in "${WsPorts[@]}"; do systemctl enable ws-proxy@$port; systemctl restart ws-proxy@$port; done

# Nginx & Squid
rm -rf /home/vps/public_html /etc/nginx/sites-* /etc/nginx/nginx.conf; mkdir -p /home/vps/public_html
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css; autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off; include /etc/nginx/mime.types; default_type application/octet-stream; access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log; client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m; fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

rm -rf /etc/squid/squid.con*
cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl ports_ port 14 22 53 21 8081 8000 3128 443 80 8080 8880 2082 2086
http_port Squid_Port1
http_port Squid_Port2
http_access allow server
http_access deny all
http_access allow all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/nginx/*.log { 
    rotate 7; 
    daily; 
    maxsize 50M; 
    missingok; 
    notifempty; 
    compress; 
    delaycompress; 
    sharedscripts; 
    postrotate; 
        /bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true; 
        /bin/systemctl kill -s USR1 nginx.service >/dev/null 2>&1 || true;
    endscript; 
}
logrotate
chown root:root /var/log; chmod 755 /var/log; chown syslog:adm /var/log/syslog; chmod 640 /var/log/syslog
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache

# ==========================================
# SYSTEM & CONNTRACK TUNING
# ==========================================
modprobe nf_conntrack 2>/dev/null || true; echo "nf_conntrack" > /etc/modules-load.d/freenet.conf
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
fs.file-max = 1048576
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
SYSCTL

sed -i 's/.*SystemMaxUse.*/SystemMaxUse=10M/' /etc/systemd/journald.conf
sed -i 's/.*Storage.*/Storage=volatile/' /etc/systemd/journald.conf
grep -q "^SystemMaxUse=10M" /etc/systemd/journald.conf || echo "SystemMaxUse=10M" >> /etc/systemd/journald.conf
grep -q "^Storage=volatile" /etc/systemd/journald.conf || echo "Storage=volatile" >> /etc/systemd/journald.conf
systemctl restart systemd-journald
sysctl --system || true

cat <<'EOF' > /etc/rsyslog.d/99-vpn-discard.conf
:programname, isequal, "dropbear" stop
:programname, isequal, "sslh" stop
:programname, isequal, "sshd" stop
:programname, isequal, "stunnel" stop
EOF
systemctl restart rsyslog
mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# Creating startup script
cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid

iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
deekayz

sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup

cat <<'deekayx' > /etc/systemd/system/deekaystartup.service
[Unit]
Description=Custom startup script
ConditionPathExists=/etc/deekaystartup
[Service]
Type=oneshot
ExecStart=/etc/deekaystartup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
deekayx
chmod +x /etc/deekaystartup; systemctl enable deekaystartup

# VNSTAT INITIALIZATION
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat
systemctl restart vnstat

# MENU CREATION
mkdir -p /usr/local/bin
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

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)

server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid nginx ws-proxy@80; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 6 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}ISSUES DETECTED${NC}"
}
pause_return() { echo; read -rp "Press ENTER to return... " _; }

list_real_users() { awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null; }

select_user() {
  local purpose="$1"
  mapfile -t USERS < <(list_real_users)
  if [ "${#USERS[@]}" -eq 0 ]; then echo -e "${RED}No active user accounts found.${NC}"; return 1; fi
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!USERS[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${USERS[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Back\n"
  read -rp "  Select an account number: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return 1
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}" ]; then echo -e "${RED}  Invalid selection.${NC}"; return 1; fi
  SELECTED_USER="${USERS[$((idx-1))]}"
  return 0
}

create_user() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREATE NEW SSH USER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Username: " user
  read -rp "  Password: " pass
  read -rp "  Valid for (days): " days

  if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$days" ]; then echo -e "\n${RED}  Error: All fields are required.${NC}"; pause_return; return; fi
  if id "$user" >/dev/null 2>&1; then echo -e "\n${RED}  Error: User '$user' already exists.${NC}"; pause_return; return; fi

  useradd -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" && echo "$user:$pass" | chpasswd
  IP=$(curl -s ipv4.icanhazip.com)

  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}ACCOUNT CREATED SUCCESSFULLY${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}Domain/Host${NC}: ${YELLOW}$DOMAIN${NC}"
  echo -e "  ${BOLD}IP Address${NC} : ${YELLOW}$IP${NC}"
  echo -e "  ${BOLD}Username${NC}   : ${YELLOW}$user${NC}"
  echo -e "  ${BOLD}Password${NC}   : ${YELLOW}$pass${NC}"
  echo -e "  ${BOLD}Expiry${NC}     : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  SSH Port    : 22, 299"
  echo -e "  Dropbear    : 80"
  echo -e "  SSL/TLS     : 443"
  echo -e "  SSL Payload : 443"
  echo -e "  WebSocket   : 80, 8080, 8880, 2082, 2086"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}Payload HTTP     :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e ""
  echo -e "  ${BOLD}Payload Enhanced :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "DELETE SSH USER"; then pause_return; return; fi
  clear; echo -e "${RED}Warning: You are about to delete user: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Are you sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    pkill -u "$SELECTED_USER" 2>/dev/null
    if userdel -r -f "$SELECTED_USER" 2>/dev/null || userdel -f "$SELECTED_USER" 2>/dev/null; then
        echo -e "${GREEN}User $SELECTED_USER has been deleted.${NC}"
    else
        echo -e "${RED}Failed to delete $SELECTED_USER. Check for locked files.${NC}"
    fi
  fi
  pause_return
}

extend_user() {
  if ! select_user "EXTEND USER EXPIRY"; then pause_return; return; fi
  clear; echo -e "Extending account for: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Enter number of days to add: " days
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number format.${NC}"; pause_return; return; fi
  current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
  if [ "$current" = "never" ] || [ -z "$current" ]; then new_exp=$(date -d "+$days days" +%Y-%m-%d)
  else new_exp=$(date -d "$current +$days days" +%Y-%m-%d); fi
  chage -E "$new_exp" "$SELECTED_USER"
  echo -e "${GREEN}Success!${NC} Account extended.\nNew Expiry Date: ${YELLOW}$new_exp${NC}"
  pause_return
}

restart_service() {
  local service_name="$1"
  local display_name="$2"
  echo -e "Restarting ${display_name}..."
  systemctl restart $service_name 2>/dev/null || true
  echo -e "${GREEN}✔ ${display_name} restarted.${NC}"
}

service_control_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}SERVICE CONTROLS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] Restart All Services"
    echo -e "  [${YELLOW}02${NC}] Restart SSH & Dropbear"
    echo -e "  [${YELLOW}03${NC}] Restart Node WebSocket Proxies"
    echo -e "  [${YELLOW}04${NC}] Restart Stunnel"
    echo -e "  [${YELLOW}05${NC}] Restart Squid Proxy & Nginx"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) restart_service "ssh dropbear stunnel4 sslh squid nginx ws-proxy@80 ws-proxy@8080 ws-proxy@8880 ws-proxy@2082 ws-proxy@2086" "All Services"; pause_return ;;
      2|02) restart_service "ssh dropbear" "SSH & Dropbear"; pause_return ;;
      3|03) restart_service "ws-proxy@80 ws-proxy@8080 ws-proxy@8880 ws-proxy@2082 ws-proxy@2086" "Node WebSocket Proxies"; pause_return ;;
      4|04) restart_service "stunnel4" "Stunnel"; pause_return ;;
      5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

utilities_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}SYSTEM UTILITIES${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}1${NC}] Enable Native Kernel BBR (Fast & Silent)"
    echo -e "  [${YELLOW}2${NC}] Check Netflix & Streaming Unlocks (English)"
    echo -e "  [${YELLOW}0${NC}] Back\n"
    read -rp "  Select an option: " subopt
    case "$subopt" in 
      1) 
         echo -e "\nEnabling Native Kernel BBR..."
         sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
         sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
         echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
         echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
         sysctl -p >/dev/null 2>&1
         if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null)" == *"bbr"* ]]; then echo -e "${GREEN}✔ BBR Successfully Enabled!${NC}"
         else echo -e "${RED}✖ Failed to enable BBR (Kernel might not support it).${NC}"; fi
         pause_return
         ;; 
      2) 
         clear
         echo -e "${YELLOW}Running Region Restriction Check (English)...${NC}\n"
         bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en
         echo ""
         pause_return 
         ;;
      0) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

change_domain() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CHANGE SERVER DOMAIN${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_dom=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || echo "Not Set")
    echo -e " Current Domain/IP: ${YELLOW}$current_dom${NC}\n"
    read -rp " Enter New Domain or IP: " new_dom
    if [ -n "$new_dom" ]; then
        echo "$new_dom" > /etc/deekayvpn/domain.txt; DOMAIN="$new_dom"
        echo -e "\n${GREEN}✔ Domain successfully updated to: $new_dom${NC}"
    else echo -e "\n${RED}Action cancelled.${NC}"; fi
    pause_return
}

advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}ADVANCED SETTINGS${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] View Service Action Logs (Journalctl)"
    echo -e "  [${YELLOW}02${NC}] Change Server Domain/IP"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) 
        clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Stunnel\n"
        read -rp "Select log: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy@80 -n 50 --no-pager ;;
          3) journalctl -u stunnel4 -n 50 --no-pager ;;
        esac; pause_return ;;
      2|02) change_domain ;;
      0|00) break ;;
    esac
  done
}

draw_header() {
  local os_name=$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')
  local os_ver=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
  local os="${os_name} ${os_ver}"
  local arch=$(uname -m)
  local cores=$(cpu_count)
  local ip=$(server_ip)
  local time=$(date '+%H:%M %Z')
  local status=$(server_status)
  local ram=$(ram_percent)
  local cpu=$(cpu_percent)
  local buf=$(buffer_mem)

  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}GodTech${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Plus${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} ${YELLOW}%s${NC}\n" "OS:" "$os" "Arch:" "$arch" "Cores:" "$cores"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} %s\n" "IP:" "$ip" "Time:" "$time" "Status:" "$status"
  echo -e "${CYAN}------------------------ ${BOLD}PROTOCOL PORTS${NC} ${CYAN}------------------------${NC}"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSH:" "22, 299" "System-DNS:" "53"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Dropbear:" "80" "WEB-Nginx:" "85"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSL:" "443" "Squid:" "3128, 8000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} \n" "WS/PYTHON:" "80, 8080, 8880, 2082, 2086" "SLL/PYTHON:" "443"
  echo -e "${CYAN}----------------------- ${BOLD}SYSTEM RESOURCES${NC} ${CYAN}-----------------------${NC}"
  printf "  ${WHITE}%-10s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-10s${NC} ${YELLOW}%-10s${NC} ${WHITE}%-8s${NC} ${YELLOW}%s${NC}\n" "RAM Used:" "$ram" "CPU Used:" "$cpu" "Buffer:" "$buf"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] SSH Account Management"
  echo -e "  [${YELLOW}02${NC}] Service Controls"
  echo -e "  [${YELLOW}03${NC}] System Utilities (BBR & Netflix)"
  echo -e "  [${YELLOW}04${NC}] Advanced Settings (Domain / Logs)"
  echo -e "  [${YELLOW}05${NC}] Reboot Server"
  echo -e "  [${RED}00${NC}] Exit\n"
  read -rp "  ► Select an option: " opt
  case "$opt" in
    1|01) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}SSH ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create SSH User\n  [${YELLOW}2${NC}] Extend User Expiry\n  [${YELLOW}3${NC}] Delete SSH User\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02) service_control_menu ;;
    3|03) utilities_menu ;;
    4|04) advanced_menu ;;
    5|05) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

# === Auto-Create Predefined SSH Users ===
echo "Creating predefined SSH users..."

PREDEFINED_USERS=(
  "deon:0000"
  "febo:0000"
  "geto:0000"
  "weon:0000"
  "ceon:0000"
)

for entry in "${PREDEFINED_USERS[@]}"; do
  IFS=':' read -r uname upass <<< "$entry"
  
  if ! id "$uname" >/dev/null 2>&1; then
    useradd -e "$(date -d "+365 days" +%Y-%m-%d)" -s /bin/false -M "$uname"
    echo "$uname:$upass" | chpasswd
    echo " ✔ Successfully created user: $uname"
  else
    echo " ✖ User $uname already exists. Skipping."
  fi
done
# ========================================

# Finishing
chown -R www-data:www-data /home/vps/public_html
clear
figlet GodTech Script -c | lolcat
echo "       Installation Complete! System need to reboot to apply all changes! "
history -c; rm /root/full.sh 2>/dev/null || true
echo "           Server will reboot in 10 seconds! "
sleep 10
reboot
