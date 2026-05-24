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
echo "              Guruz GH SSH Script Installer"
echo "============================================================"
echo ""
echo "Supported Operating Systems:"
echo ""
echo "  ✔ Debian 13              (Supported)"
echo "  ✔ Debian 12              (supported)"
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

#Script Variables
read -p "Enter your Domain/Subdomain for Xray (or press enter for IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='299'

# Dropbear Ports
Dropbear_Port1='790'
Dropbear_Port2='550'

# Stunnel Ports (Internal Fallback)
Stunnel_Port='127.0.0.1:4443'
Stunnel_Port_Num='4443' 

# Squid Ports
Squid_Port1='3128'
Squid_Port2='8000'

# Node.js Socks Proxy (Isolated Ports)
WsPorts=('10080' '25' '2082' '2086')  
WsPort='10080'  

# SSLH Port
MainPort='666' 

# SSH SlowDNS
read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

# UDP HYSTERIA | UDP PORT | OBFS | PASSWORDS
UDP_PORT=":36712"
UDP_PORT2=":36713"
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

# DNS Resolver cloudflare dns
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'

# Server local time
MyVPS_Time='Africa/Accra'

# Telegram IDs
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

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

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

command -v ss >/dev/null 2>&1 || apt-get install -y iproute2
command -v netfilter-persistent >/dev/null 2>&1 || apt-get install -y netfilter-persistent iptables-persistent
command -v jq >/dev/null 2>&1 || apt-get install -y jq
command -v curl >/dev/null 2>&1 || apt-get install -y curl

if ! systemctl list-unit-files | grep -q "^${STUNNEL_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^stunnel\.service"; then STUNNEL_SERVICE="stunnel"; fi
fi
if ! systemctl list-unit-files | grep -q "^${SQUID_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^squid3\.service"; then SQUID_SERVICE="squid3"; fi
fi

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar zip gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
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

wget -q https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
rm -rf webmin_2.111_all.deb
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
systemctl restart webmin || true

# === HARDCODED CERTIFICATE FOR XRAY & STUNNEL ===
echo "Applying default hardcoded SSL Certificate for Xray & Stunnel..."

cat <<'EOF_KEY' > /etc/xray/xray.key
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

cat <<'EOF_CRT' > /etc/xray/xray.crt
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

chmod 644 /etc/xray/xray.crt; chmod 600 /etc/xray/xray.key

# Copy and secure Stunnel cert
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem; chown root:root /etc/stunnel/stunnel.pem

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
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
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
BANNER="/etc/zorro-luffy"
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
loc=/etc/socksproxy; mkdir -p $loc; apt-get install -y nodejs

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });
const TARGET_HOST = '127.0.0.1'; const TARGET_PORT = $Dropbear_Port1;
const LISTEN_PORT = parseInt(process.argv[2]);
if (!LISTEN_PORT) { process.exit(1); }
const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            clientSocket.write('HTTP/1.1 101 Switching Protocols\r\n\r\n');
            clientSocket.pipe(targetSocket); targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
        targetSocket.on('close', () => clientSocket.destroy());
    });
    clientSocket.on('error', () => {}); clientSocket.on('close', () => {});
};
const server = net.createServer(handleConnection);
server.listen(LISTEN_PORT, '0.0.0.0', () => { console.log(\`WS Proxy active on isolated port \${LISTEN_PORT}\`); });
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

# === XRAY CORE ===
echo "Installing Stable Xray Core v26.5.9..."
XRAY_VER="v26.5.9"
wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"
unzip -q -o /tmp/xray.zip -d /tmp/xray/
mv -f /tmp/xray/xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray
rm -rf /tmp/xray*
touch /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt

cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443, "protocol": "vless",
      "settings": { "clients": [], "decryption": "none", "fallbacks": [ { "path": "/vmess", "dest": 10001 }, { "path": "/trojan", "dest": 10002 }, { "path": "/vless", "dest": 10003 }, { "dest": 666 } ] },
      "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "alpn": ["http/1.1"], "certificates": [ { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" } ] } }
    },
    { "listen": "127.0.0.1", "port": 10001, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "listen": "127.0.0.1", "port": 10002, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "port": "80,8080,8880", "protocol": "vless", "settings": { "clients": [], "decryption": "none", "fallbacks": [ { "path": "/vless", "dest": 10003 }, { "path": "/vmess", "dest": 10004 }, { "dest": 10080 } ] }, "streamSettings": { "network": "tcp" } },
    { "listen": "127.0.0.1", "port": 10003, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "listen": "127.0.0.1", "port": 10004, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} }, { "protocol": "blackhole", "settings": {}, "tag": "blocked" } ]
}
EOF

mkdir -p /var/log/xray
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable xray; systemctl restart xray

# USER EXPIRY CRONJOB FOR XRAY
cat <<'EOF_EXP' > /usr/local/bin/exp-check
#!/bin/bash
now=$(date +%Y-%m-%d)
for proto in vless vmess trojan; do
  if [ -f "/etc/xray/${proto}.txt" ]; then
    data=( $(cat /etc/xray/${proto}.txt | awk '{print $1}') )
    for user in "${data[@]}"; do
      exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
      if [[ "$now" > "$exp" ]]; then
        jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
        sed -i "/^$user /d" /etc/xray/${proto}.txt
      fi
    done
  fi
done
systemctl restart xray
EOF_EXP
chmod +x /usr/local/bin/exp-check
echo "0 0 * * * root /usr/local/bin/exp-check >/dev/null 2>&1" > /etc/cron.d/xray-expiry

# USER EXPIRY CRONJOB FOR HYSTERIA V1 & V2
cat <<'EOF_HYST_EXP' > /usr/local/bin/hysteria-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
# Hysteria V1
if [ -f "/etc/hysteria/users.txt" ]; then
  while read -r user exp; do
    if [[ "$now" > "$exp" ]]; then
      jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" /etc/hysteria/config.json > /tmp/h.json && mv /tmp/h.json /etc/hysteria/config.json
      sed -i "/^$user /d" /etc/hysteria/users.txt
    fi
  done < "/etc/hysteria/users.txt"
  systemctl restart hysteria-v1
fi
# Hysteria V2
if [ -f "/etc/hysteria/users_v2.txt" ]; then
  while read -r user exp_date exp_time; do
    exp_seconds=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
    now_seconds=$(date +%s)
    if [ "$now_seconds" -ge "$exp_seconds" ]; then sed -i "/^$user /d" /etc/hysteria/users_v2.txt; fi
  done < "/etc/hysteria/users_v2.txt"
fi
EOF_HYST_EXP
chmod +x /usr/local/bin/hysteria-exp
echo "0 * * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry

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
acl ports_ port 14 22 53 21 8081 25 8000 3128 443 80 8080 8880 2082 2086 36712
http_port Squid_Port1
http_port Squid_Port2
http_access allow server
http_access deny all
http_access allow all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

# Health Checks
mkdir -p /etc/deekayvpn/health
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash
MYID="MYCHATID"; KEY="MYBOTID"; URL="https://api.telegram.org/bot${KEY}/sendMessage"
send_telegram_message() { curl -s --max-time 10 --retry 5 --retry-delay 2 --retry-max-time 10 -d "chat_id=${MYID}&text=$1&disable_web_page_preview=true&parse_mode=markdown" "${URL}" >/dev/null 2>&1; }
server_ip="IPADDRESS"; datenow=$(date +"%Y-%m-%d %T"); IPCOUNTRY=$(curl -s "https://freeipapi.com/api/json/${server_ip}" | jq -r '.countryName')
STATE_DIR="/etc/deekayvpn/health"
check_port() { ss -lnt | awk '{print $4}' | grep -q ":$1$"; }
mark_fail() { local f="$STATE_DIR/$1.fail"; local n=0; [ -f "$f" ] && n=$(cat "$f"); n=$((n+1)); echo "$n" > "$f"; echo "$n"; }
clear_fail() { rm -f "$STATE_DIR/$1.fail"; }
restart_after_3_fails() {
    local fails=$(mark_fail "$1")
    if [ "$fails" -ge 3 ]; then
        systemctl restart "$2" >/dev/null 2>&1
        send_telegram_message "Service *$2* was offline or missing port(s) *$3* on server *${IPCOUNTRY}* ($server_ip). It has been auto-restarted at *${datenow}*."
        clear_fail "$1"
    fi
}
if check_port SSHPORT1 && check_port SSHPORT2 && systemctl is-active --quiet ssh; then clear_fail ssh; else restart_after_3_fails ssh ssh "SSHPORT1,SSHPORT2"; fi
if check_port DROPBEARPORT1 && check_port DROPBEARPORT2 && systemctl is-active --quiet dropbear; then clear_fail dropbear; else restart_after_3_fails dropbear dropbear "DROPBEARPORT1,DROPBEARPORT2"; fi
if check_port STUNNELPORT && systemctl is-active --quiet stunnel4; then clear_fail stunnel4; else restart_after_3_fails stunnel4 stunnel4 "STUNNELPORT"; fi
if check_port SSLHPORT && systemctl is-active --quiet sslh; then clear_fail sslh; else restart_after_3_fails sslh sslh "SSLHPORT"; fi
if check_port SQUIDPORT1 && check_port SQUIDPORT2 && systemctl is-active --quiet squid; then clear_fail squid; else restart_after_3_fails squid squid "SQUIDPORT1,SQUIDPORT2"; fi
if check_port NGINXPORT && systemctl is-active --quiet nginx; then clear_fail nginx; else restart_after_3_fails nginx nginx "NGINXPORT"; fi
for port in 10080 25 2082 2086; do if check_port $port && systemctl is-active --quiet ws-proxy@$port; then clear_fail ws-proxy-$port; else restart_after_3_fails ws-proxy-$port ws-proxy@$port "$port"; fi; done
if check_port 443 && systemctl is-active --quiet xray; then clear_fail xray; else restart_after_3_fails xray xray "443, 80"; fi
if systemctl is-active --quiet hysteria-v1; then clear_fail hysteria-v1; else restart_after_3_fails hysteria-v1 hysteria-v1 "UDP"; fi
if systemctl is-active --quiet hysteria-server; then clear_fail hysteria-server; else restart_after_3_fails hysteria-server hysteria-server "UDP"; fi
ServiceChecker

chmod 755 /etc/deekayvpn/service_checker.sh
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT1|$Dropbear_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT2|$Dropbear_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|STUNNELPORT|$Stunnel_Port_Num|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh

echo "*/3 * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker
rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/xray/access.log /var/log/xray/error.log { rotate 7; daily; missingok; notifempty; compress; delaycompress; sharedscripts; postrotate; /usr/lib/rsyslog/rsyslog-rotate; endscript; }
logrotate
chown root:root /var/log; chmod 755 /var/log; chown syslog:adm /var/log/syslog; chmod 640 /var/log/syslog
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache

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
sysctl --system || true
mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# SLOWDNS
rm -rf /etc/slowdns; mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS
After=network.target
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :53 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload; systemctl enable server-sldns; systemctl restart server-sldns

# === HYSTERIA v1 (Sing-box v1.8.14 - Last Supported Version) & WARP ===
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install -y cloudflare-warp
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new; warp-cli --accept-tos mode proxy; warp-cli --accept-tos connect

wget -qO /tmp/sing-box.deb "https://github.com/SagerNet/sing-box/releases/download/v1.8.14/sing-box_1.8.14_linux_amd64.deb"
dpkg -i /tmp/sing-box.deb
apt-mark hold sing-box
rm -f /tmp/sing-box.deb

mkdir -p /etc/hysteria
HYST_PORT="${UDP_PORT##*:}"

cat > /etc/hysteria/config.json <<EOF
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria",
      "tag": "hy1-inbound",
      "listen": "0.0.0.0",
      "listen_port": $HYST_PORT,
      "up_mbps": 100, "down_mbps": 100,
      "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "/etc/xray/xray.crt", "key_path": "/etc/xray/xray.key" }
    }
  ],
  "outbounds": [
    { "type": "socks", "tag": "warp-proxy", "server": "127.0.0.1", "server_port": 40000 },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      {
        "inbound": "hy1-inbound",
        "network": "udp",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
        "outbound": "block"
      },
      {
        "inbound": "hy1-inbound",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
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
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/hysteria/users.txt

cat > /etc/systemd/system/hysteria-v1.service <<EOF
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
systemctl daemon-reload; systemctl enable hysteria-v1.service; systemctl start hysteria-v1.service

# === NATIVE HYSTERIA v2 ===
bash <(curl -fsSL https://get.hy2.sh/) >/dev/null 2>&1

cat << 'EOF' > /etc/hysteria/auth.sh
#!/bin/bash
ADDR="$1"; AUTH="$2"; TX="$3"
USER_DB="/etc/hysteria/users_v2.txt"
USER_ENTRY=$(grep -w "^$AUTH" "$USER_DB" 2>/dev/null)
if [ -z "$USER_ENTRY" ]; then exit 1; fi
EXP_DATE=$(echo "$USER_ENTRY" | cut -d' ' -f2-)
EXP_SECONDS=$(date -d "$EXP_DATE" +%s 2>/dev/null)
NOW_SECONDS=$(date +%s)
if [ -z "$EXP_SECONDS" ] || [ "$NOW_SECONDS" -ge "$EXP_SECONDS" ]; then exit 1; fi
echo "$AUTH"
exit 0
EOF
chmod +x /etc/hysteria/auth.sh; touch /etc/hysteria/users_v2.txt

cat << EOF > /etc/hysteria/hy2.json
{
  "listen": ":50001-60000",
  "tls": { "cert": "/etc/xray/xray.crt", "key": "/etc/xray/xray.key" },
  "bandwidth": { "up": "1 gbps", "down": "1 gbps" },
  "ignoreClientBandwidth": false,
  "obfs": { "type": "salamander", "salamander": { "password": "GuruzScript" } },
  "auth": { "type": "command", "command": "/etc/hysteria/auth.sh" },
  "masquerade": { "type": "proxy", "proxy": { "url": "https://bing.com", "rewriteHost": true } },
  "outbounds": [ { "name": "warp", "type": "socks5", "socks5": { "addr": "127.0.0.1:40000" } }, { "name": "direct", "type": "direct" } ],
  "acl": {
    "inline": [
      "domain(doubleclick.net) -> warp", "domain(googlesyndication.com) -> warp", "domain(googleadservices.com) -> warp",
      "domain(admob.com) -> warp", "domain(google-analytics.com) -> warp", "domain(app-measurement.com) -> warp",
      "domain(adservice.google.com) -> warp", "domain(g.doubleclick.net) -> warp", "domain(google.com) -> warp",
      "domain(pagead2.googlesyndication.com) -> warp", "domain(tpc.googlesyndication.com) -> warp", "domain(googlevideo.com) -> warp",
      "domain(gvt1.com) -> warp", "domain(gvt2.com) -> warp", "domain(gvt3.com) -> warp", "domain(ytimg.com) -> warp",
      "domain(youtube.com) -> warp", "domain(gstatic.com) -> warp", "domain(googleusercontent.com) -> warp", "domain(ggpht.com) -> warp",
      "domain(play.google.com) -> warp", "domain(firebaseio.com) -> warp", "domain(firebase.googleapis.com) -> warp",
      "domain(crashlytics.com) -> warp", "domain(fundingchoicesmessages.google.com) -> warp", "domain(imasdk.googleapis.com) -> warp",
      "domain(googleanalytics.com) -> warp", "domain(analytics.google.com) -> warp", "domain(fcm.googleapis.com) -> warp",
      "domain(mtalk.google.com) -> warp", "domain(firebaseinstallations.googleapis.com) -> warp", "domain(firebaselogging.googleapis.com) -> warp",
      "domain(firebaselogging-pa.googleapis.com) -> warp", "domain(firebaseremoteconfig.googleapis.com) -> warp",
      "domain(googleadapis.com) -> warp", "domain(accounts.google.com) -> warp", "domain(play.googleapis.com) -> warp",
      "domain(android.apis.google.com) -> warp", "domain(adsense.com) -> warp", "domain(1e100.net) -> warp",
      "all -> direct"
    ]
  }
}
EOF

cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria V2 Native Server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/hy2.json
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-server.service; systemctl start hysteria-server.service

# NAT & Iptables Configuration
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore Hysteria UDP NAT rules
After=network-online.target
Wants=network-online.target
Before=hysteria-v1.service hysteria-server.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport 50001:60000 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 50001:60000 -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-nat.service; systemctl start hysteria-nat.service

# Creating startup script
cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
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
systemctl enable badvpn; systemctl start badvpn

# MENU CREATION - FULL AND UNCOMPRESSED
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)

HYST_CONFIG_V1="/etc/hysteria/config.json"
HYST_USER_DB_V1="/etc/hysteria/users.txt"
HYST_USER_DB_V2="/etc/hysteria/users_v2.txt"

# --- Utility Functions ---
server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid nginx server-sldns hysteria-v1 hysteria-server ws-proxy@10080 xray; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}ISSUES DETECTED${NC}"
}
pause_return() { echo; read -rp "Press ENTER to return... " _; }

# --- HYSTERIA V1 FUNCTIONS (Sing-Box) ---
add_hysteria_v1() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREATE HYSTERIA V1 USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password: " new_pass
    
    if grep -qw "^$new_pass" "$HYST_USER_DB_V1" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$HYST_CONFIG_V1" >/dev/null; then
        echo -e "\n${RED}Error: User/Password already exists!${NC}"
        pause_return; return
    fi
    read -rp " Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$HYST_CONFIG_V1" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG_V1"
    echo "$new_pass $exp_date" >> "$HYST_USER_DB_V1"
    systemctl restart hysteria-v1
    
    OBFS_V1=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG_V1" 2>/dev/null || echo "GuruzScript")
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA V1 ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Domain/Host${NC}: ${YELLOW}${DOMAIN}${NC}"
    echo -e "  ${BOLD}V1 Ports${NC}   : ${YELLOW}20000-50000 ${NC}"
    echo -e "  ${BOLD}Password${NC}   : ${YELLOW}${new_pass}${NC}"
    echo -e "  ${BOLD}Obfs (V1)${NC}  : ${YELLOW}${OBFS_V1}${NC}"
    echo -e "  ${BOLD}Expiry Date${NC}: ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${BOLD}[ HYSTERIA V1 (Legacy) ]${NC}"
    echo -e "${YELLOW}hysteria://${DOMAIN:-$(server_ip)}:36712/?insecure=1&peer=${DOMAIN:-$(server_ip)}&auth=${new_pass}&obfsParam=${OBFS_V1}&upmbps=100&downmbps=100&alpn=h3#${new_pass}-HY1${NC}"
    pause_return
}

del_hysteria_v1() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}DELETE HYSTERIA V1 USER${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V1" ]; then echo -e "No V1 users found."; pause_return; return; fi
    cat -n "$HYST_USER_DB_V1" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to delete: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$HYST_USER_DB_V1" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi

    jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$HYST_CONFIG_V1" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG_V1"
    sed -i "${del_id}d" "$HYST_USER_DB_V1"
    systemctl restart hysteria-v1
    echo -e "\n${GREEN}✔ User '$del_pass' deleted successfully!${NC}"
    pause_return
}

extend_hysteria_v1() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTEND HYSTERIA V1 USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V1" ]; then echo -e "No V1 users found."; pause_return; return; fi

    cat -n "$HYST_USER_DB_V1" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Enter the ID number of the user to extend: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi
    
    ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB_V1" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB_V1" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi
    
    read -rp " Add Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB_V1"
    
    echo -e "\n${GREEN}✔ User '$ext_pass' extended successfully!${NC}\n New Expiry: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_hysteria_v1() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA V1 USERS LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V1" ]; then echo -e "\n No active V1 users found.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD (AUTH STRING)" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$HYST_USER_DB_V1" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total Active V1 Users: ${YELLOW}$(wc -l < "$HYST_USER_DB_V1")${NC}"
    fi
    pause_return
}

speed_hysteria_v1() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EDIT V1 UP/DOWN SPEEDS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_up=$(jq -r '.inbounds[0].up_mbps' "$HYST_CONFIG_V1" 2>/dev/null || echo "100")
    current_down=$(jq -r '.inbounds[0].down_mbps' "$HYST_CONFIG_V1" 2>/dev/null || echo "100")
    echo -e " Current Upload:   ${YELLOW}${current_up} Mbps${NC}"
    echo -e " Current Download: ${YELLOW}${current_down} Mbps${NC}\n"
    read -rp " Enter New Upload Speed (Mbps): " new_up
    read -rp " Enter New Download Speed (Mbps): " new_down
    if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
        jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$HYST_CONFIG_V1" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG_V1"
        systemctl restart hysteria-v1
        echo -e "\n${GREEN}✔ Speeds updated successfully!${NC}"
    else echo -e "\n${RED}Invalid input. Numbers only.${NC}"; fi
    pause_return
}

# --- HYSTERIA V2 FUNCTIONS (Native Binary) ---
add_hysteria_v2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREATE HYSTERIA V2 USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password/Auth String: " new_pass
    if grep -qw "^$new_pass" "$HYST_USER_DB_V2" 2>/dev/null; then
        echo -e "\n${RED}Error: User/Password already exists!${NC}"; pause_return; return
    fi
    echo -e "  [1] Standard User (Days)"
    echo -e "  [2] Trial Access (5 Minutes)"
    read -rp " Select Account Type: " acc_type
    
    if [ "$acc_type" == "2" ]; then exp_date=$(date -d "+5 minutes" +"%Y-%m-%d %H:%M:%S")
    else
        read -rp " Validity (Days): " days
        if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
        exp_date=$(date -d "+${days} days" +"%Y-%m-%d 23:59:59")
    fi
    
    echo "$new_pass $exp_date" >> "$HYST_USER_DB_V2"
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA V2 ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Domain/Host${NC}: ${YELLOW}${DOMAIN}${NC}"
    echo -e "  ${BOLD}V2 Ports${NC}   : ${YELLOW}50001-60000 ${NC}"
    echo -e "  ${BOLD}Password${NC}   : ${YELLOW}${new_pass}${NC}"
    echo -e "  ${BOLD}Expiry Date${NC}: ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e "${BOLD}[ HYSTERIA V2 (Native) ]${NC}"
    echo -e "${YELLOW}hysteria2://${new_pass}@${DOMAIN}:50001/?mport=50001-60000&sni=${DOMAIN}&insecure=1&obfs=salamander&obfs-password=GuruzScript#${new_pass}-HY2${NC}\n"
    pause_return
}

del_hysteria_v2() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}DELETE HYSTERIA V2 USER${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V2" ]; then echo -e "No V2 users found."; pause_return; return; fi
    cat -n "$HYST_USER_DB_V2" | awk '{print " ["$1"] User: "$2" | Exp: "$3" "$4}'
    echo ""
    read -rp " Enter ID to delete: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi
    sed -i "${del_id}d" "$HYST_USER_DB_V2"
    echo -e "\n${GREEN}✔ User deleted successfully!${NC}"
    pause_return
}

extend_hysteria_v2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTEND HYSTERIA V2 USER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V2" ]; then echo -e "No V2 users found."; pause_return; return; fi
    cat -n "$HYST_USER_DB_V2" | awk '{print " ["$1"] User: "$2" | Exp: "$3" "$4}'
    echo ""
    read -rp " Enter the ID number of the user to extend: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid ID.${NC}"; pause_return; return; fi
    
    ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB_V2" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB_V2" | awk '{print $2" "$3}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID not found.${NC}"; pause_return; return; fi
    
    read -rp " Add Validity (Days): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Invalid number.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d %H:%M:%S")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB_V2"
    echo -e "\n${GREEN}✔ User '$ext_pass' extended successfully!${NC}\n New Expiry: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_hysteria_v2() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}HYSTERIA V2 USERS LIST${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB_V2" ]; then 
        echo -e "\n No active V2 users found.\n"
    else
        printf " %-5s | %-20s | %-20s\n" "ID" "PASSWORD" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$HYST_USER_DB_V2" | while read -r num user exp_d exp_t; do
            printf " [%-3s] | %-20s | %-20s\n" "$num" "$user" "$exp_d $exp_t"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total V2 Users: ${YELLOW}$(wc -l < "$HYST_USER_DB_V2")${NC}"
    fi
    pause_return
}

# --- XRAY MANAGEMENT FUNCTIONS ---
add_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREATE XRAY ACCOUNT${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e " [1] VLESS (TLS & NTLS)"
  echo -e " [2] VMESS (TLS & NTLS)"
  echo -e " [3] TROJAN (TLS)"
  echo -e " [4] ALL-IN-ONE (VLESS + VMESS + TROJAN)"
  read -rp " Select Protocol: " prot
  read -rp " Username: " user
  
  if grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
    echo -e "${RED}Username already exists!${NC}"; pause_return; return
  fi

  read -rp " Validity (Days): " masa
  exp=$(date -d "+${masa} days" +"%Y-%m-%d")
  uuid=$(cat /proc/sys/kernel/random/uuid)
  pass="Guruz${uuid:0:6}"
  
  if [ "$prot" == "1" ]; then
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[3].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[4].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vless.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}VLESS ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Username : $user\nExpiry   : $exp"
    echo -e "\n${YELLOW}TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}NTLS (80/8080/8880):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  
  elif [ "$prot" == "2" ]; then
    jq ".inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[5].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}VMESS ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Username: $user\nExpiry: $exp"
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "\n${YELLOW}TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}NTLS (80/8080/8880):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  
  elif [ "$prot" == "3" ]; then
    jq ".inbounds[2].settings.clients += [{\"password\": \"$pass\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $pass $exp" >> /etc/xray/trojan.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}TROJAN ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Username: $user\nPassword: $pass\nExpiry: $exp"
    echo -e "\n${YELLOW}TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"

  elif [ "$prot" == "4" ]; then
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[3].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[4].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}] | .inbounds[5].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}] | .inbounds[2].settings.clients += [{\"password\": \"$pass\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    
    echo "$user $uuid $exp" >> /etc/xray/vless.txt
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
    echo "$user $pass $exp" >> /etc/xray/trojan.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}ALL-IN-ONE ACCOUNT CREATED${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Username: $user\nExpiry:   $exp"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    echo -e "\n${YELLOW}[ VLESS TLS (443) ]${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}[ VLESS NTLS (80) ]${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}"
    
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "\n${YELLOW}[ VMESS TLS (443) ]${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}[ VMESS NTLS (80) ]${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)"

    echo -e "\n${YELLOW}[ TROJAN TLS (443) ]${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  fi
  systemctl restart xray
  pause_return
}

del_xray() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}DELETE XRAY ACCOUNT${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  
  mapfile -t users < <(cat /etc/xray/*.txt 2>/dev/null | awk '{print $1}' | sort -u)
  
  if [ ${#users[@]} -eq 0 ]; then 
      echo -e "${YELLOW}No Xray users found.${NC}"; pause_return; return
  fi
  for i in "${!users[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${users[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancel\n"

  read -rp "  Select user to delete: " idx
  if [[ "$idx" == "00" || "$idx" == "0" ]]; then return; fi
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -le 0 ] || [ "$idx" -gt "${#users[@]}" ]; then 
      echo -e "${RED}Invalid selection.${NC}"; pause_return; return 
  fi

  user="${users[$((idx-1))]}"
  jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
  sed -i "/^$user /d" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null
  systemctl restart xray
  echo -e "\n${GREEN}✔ User $user deleted successfully.${NC}"
  pause_return
}

renew_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RENEW XRAY ACCOUNT${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Username to renew: " user
  
  if ! grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then 
    echo -e "${RED}User not found.${NC}"; pause_return; return
  fi
  read -rp " Add Validity (Days): " days
  for proto in vless vmess trojan; do 
    if grep -qw "^$user" "/etc/xray/${proto}.txt"; then
      current_exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
      new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
      sed -i "s/^$user .* $current_exp/$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $1 " " $2}') $new_exp/" "/etc/xray/${proto}.txt"
    fi
  done
  echo -e "\n${GREEN}✔ User '$user' renewed successfully.${NC}\nNew Expiry: $new_exp"
  pause_return
}

show_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}SHOW XRAY CONFIG LINKS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Username to view: " user
  local found=0
  if grep -qw "^$user" /etc/xray/vless.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vless.txt | awk '{print $2}')
    echo -e "${YELLOW}VLESS TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}VLESS NTLS (80):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/vmess.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vmess.txt | awk '{print $2}')
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "${YELLOW}VMESS TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}VMESS NTLS (80):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/trojan.txt; then
    pass=$(grep -w "^$user" /etc/xray/trojan.txt | awk '{print $2}')
    echo -e "${YELLOW}TROJAN TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}\n"
    found=1
  fi
  if [ "$found" -eq 0 ]; then echo -e "${RED}User not found in any protocol.${NC}"; fi
  pause_return
}

# --- SSH USER FUNCTIONS ---
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
  CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')

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
  echo -e "  SSH Port   : 22, 299"
  echo -e "  Dropbear   : 80"
  echo -e "  SSL/TLS    : 443"
  echo -e "  SSL/WS     : 443"
  echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086, 25"
  echo -e "  SlowDNS    : 53"
  echo -e "  BadVPN     : 7300"
  echo -e "  Hysteria V1: 20000-50000"
  echo -e "  Hysteria V2: 50001-60000"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}Payload HTTP     :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e ""
  echo -e "  ${BOLD}Payload Enhanced :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-Not Set}${NC}"
  echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "DELETE SSH USER"; then pause_return; return; fi
  clear; echo -e "${RED}Warning: You are about to delete user: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Are you sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    userdel -r "$SELECTED_USER" 2>/dev/null || userdel "$SELECTED_USER" 2>/dev/null
    echo -e "${GREEN}User $SELECTED_USER has been deleted.${NC}"
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

# --- Monitor ---
online_users() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "               ${BOLD}ACTIVE USER SESSIONS MONITOR${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

  echo -e "${YELLOW}--- LEGACY SSH & DROPBEAR ---${NC}"
  declare -A active_ssh
  mapfile -t USERS < <(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null)
  
  for user in "${USERS[@]}"; do
      ssh_count=$(ps -u "$user" 2>/dev/null | grep -c "sshd")
      drop_count=$(ps -ef 2>/dev/null | grep -i "dropbear" | grep -w "$user" | grep -v grep | wc -l)
      total=$((ssh_count + drop_count))
      if [ "$total" -gt 0 ]; then active_ssh["$user"]=$total; fi
  done

  if [ "${#active_ssh[@]}" -eq 0 ]; then 
      echo -e "  No authenticated legacy SSH users are currently online.\n"
  else
    printf "  %-25s %-15s\n" "USERNAME" "ACTIVE SESSIONS"
    echo -e "${CYAN}  ----------------------------------------------------------${NC}"
    for user in "${!active_ssh[@]}"; do 
        if [ "${active_ssh[$user]}" -gt 1 ]; then
            printf "  %-25s ${RED}%-15s (Multi-Login)${NC}\n" "$user" "${active_ssh[$user]}"
        else
            printf "  %-25s ${GREEN}%-15s${NC}\n" "$user" "${active_ssh[$user]}"
        fi
    done | sort
    echo
  fi

  echo -e "${YELLOW}--- XRAY CORE ACTIVE LOGINS (Recent Unique IPs) ---${NC}"
  if grep -q '"loglevel": "warning"' /etc/xray/config.json 2>/dev/null; then
      sed -i 's/"loglevel": "warning"/"loglevel": "info"/g' /etc/xray/config.json
      systemctl restart xray 2>/dev/null
      echo -e "  [System Note] Xray logging enabled. Reconnect users to see logs.\n"
  elif [ -f /var/log/xray/access.log ]; then
      active_xray=$(tail -n 10000 /var/log/xray/access.log 2>/dev/null | grep "accepted" | awk '{ user=""; for(i=1;i<=NF;i++) if($i=="email:") user=$(i+1); if(user!="") { split($3, a, ":"); print user " " a[1] } }' | sort -u | awk '{print $1}' | uniq -c | sort -nr)
      if [ -z "$active_xray" ]; then 
          echo -e "  No active Xray users found in recent logs.\n"
      else
          printf "  %-15s %-25s\n" "UNIQUE IPs" "USERNAME"
          echo -e "${CYAN}  ----------------------------------------------------------${NC}"
          while read -r count username; do 
              if [ -n "$username" ]; then 
                  if [ "$count" -gt 1 ]; then
                      printf "  ${RED}%-15s${NC} %-25s ${RED}(Multi-IP)${NC}\n" "$count" "$username"
                  else
                      printf "  %-15s %-25s\n" "$count" "$username"
                  fi
              fi
          done <<< "$active_xray"
      fi
  else echo -e "  Xray access log not found.\n"; fi
  
  pause_return
}

# --- Service Controls ---
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
    echo -e "  [${YELLOW}04${NC}] Restart Stunnel & Xray Core"
    echo -e "  [${YELLOW}05${NC}] Restart Squid Proxy & Nginx"
    echo -e "  [${YELLOW}06${NC}] Restart UDP Core (SlowDNS / Hysteria / BadVPN)"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) restart_service "ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-v1 hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray" "All Services"; pause_return ;;
      2|02) restart_service "ssh dropbear" "SSH & Dropbear"; pause_return ;;
      3|03) restart_service "ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086" "Node WebSocket Proxies"; pause_return ;;
      4|04) restart_service "stunnel4 xray" "Stunnel & Xray Core"; pause_return ;;
      5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
      6|06) restart_service "server-sldns hysteria-v1 hysteria-server badvpn" "UDP Core Services"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Backup & Restore ---
backup_snapshot() {
  clear; local out="/root/guruzgh_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo -e "Packaging server configurations..."
  tar -czf "$out" /etc/ssh /etc/default/dropbear /etc/stunnel /etc/squid /etc/hysteria /etc/deekayvpn /etc/systemd/system/ws-proxy@.service /etc/xray 2>/dev/null
  echo -e "\n${GREEN}✔ Backup successfully created!${NC}\nLocation: ${YELLOW}$out${NC}"
  pause_return
}

restore_snapshot() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RESTORE CONFIGURATION${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  shopt -s nullglob
  backups=(/root/guruzgh_backup_*.tar.gz)
  if [ ${#backups[@]} -eq 0 ]; then echo -e "${RED}  No backup files found in /root/.${NC}"; pause_return; return; fi
  echo -e "  Available Backups:\n"
  for i in "${!backups[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancel\n"
  read -rp "  Select backup to restore: " sel
  if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
  idx=$((sel-1))
  if [ -n "${backups[$idx]}" ]; then
    echo -e "\nRestoring ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
    tar -xzf "${backups[$idx]}" -C /
    systemctl daemon-reload; systemctl restart ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-v1 hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray 2>/dev/null || true
    echo -e "${GREEN}✔ Restore complete!${NC}"
  else echo -e "${RED}Invalid selection.${NC}"; fi
  pause_return
}

# --- System Utilities ---
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

# --- Domain & DNS Management ---
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

change_slowdns() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}CHANGE SLOWDNS NAMESERVER${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    svc_file="/etc/systemd/system/server-sldns.service"
    if [ ! -f "$svc_file" ]; then echo -e "${RED}SlowDNS service file not found.${NC}"; pause_return; return; fi
    current_ns=$(grep 'ExecStart=' "$svc_file" | sed 's/.*server\.key \([^ ]*\) .*/\1/')
    echo -e " Current Nameserver: ${YELLOW}$current_ns${NC}\n"
    read -rp " Enter New Nameserver (e.g., ns1.domain.com): " new_ns
    if [ -n "$new_ns" ] && [ "$new_ns" != "$current_ns" ]; then
        sed -i "s/$current_ns/$new_ns/g" "$svc_file"
        systemctl daemon-reload; systemctl restart server-sldns
        echo -e "\n${GREEN}✔ SlowDNS Nameserver updated to: $new_ns${NC}"
    else echo -e "\n${RED}Action cancelled or identical NS entered.${NC}"; fi
    pause_return
}

# --- Advanced / Danger Zone ---
advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}ADVANCED SETTINGS${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] View Raw Hysteria JSON"
    echo -e "  [${YELLOW}02${NC}] View Service Action Logs (Journalctl)"
    echo -e "  [${YELLOW}03${NC}] Change Server Domain/IP"
    echo -e "  [${YELLOW}04${NC}] Change SlowDNS Nameserver (NS)"
    echo -e "  [${RED}05${NC}] Full Script Uninstall (Danger)"
    echo -e "  [${YELLOW}00${NC}] Back\n"
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "Not found."; pause_return ;;
      2|02) 
        clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Hysteria V1  [4] Hysteria V2  [5] SlowDNS  [6] Xray\n"
        read -rp "Select log: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy@10080 -n 50 --no-pager ;;
          3) journalctl -u hysteria-v1 -n 50 --no-pager ;;
          4) journalctl -u hysteria-server -n 50 --no-pager ;;
          5) journalctl -u server-sldns -n 50 --no-pager ;;
          6) journalctl -u xray -n 50 --no-pager ;;
        esac; pause_return ;;
      3|03) change_domain ;;
      4|04) change_slowdns ;;
      5|05) remove_script ;;
      0|00) break ;;
    esac
  done
}

remove_script() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                     ${BOLD}FULL UNINSTALL${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Are you absolutely sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo -e "\nStopping services..."
      systemctl stop ws-proxy@* server-sldns badvpn hysteria-v1 hysteria-server sslh stunnel4 squid dropbear nginx xray 2>/dev/null || true
      systemctl disable ws-proxy@* server-sldns badvpn hysteria-v1 hysteria-server xray 2>/dev/null || true
      echo "Deleting files..."
      rm -f /etc/systemd/system/ws-proxy@.service /etc/systemd/system/server-sldns.service /etc/systemd/system/badvpn.service /etc/systemd/system/xray.service
      rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/cron.d/xray-expiry /etc/cron.d/hysteria-expiry /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
      rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /etc/xray /etc/hysteria /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
      systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
      echo -e "${GREEN}✔ Removal complete.${NC}"
  else echo "Cancelled."; fi
  pause_return
}

# --- Main Dashboard ---
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
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}Guruz GH${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Plus${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} ${YELLOW}%s${NC}\n" "OS:" "$os" "Arch:" "$arch" "Cores:" "$cores"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} %s\n" "IP:" "$ip" "Time:" "$time" "Status:" "$status"
  echo -e "${CYAN}------------------------ ${BOLD}PROTOCOL PORTS${NC} ${CYAN}------------------------${NC}"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSH:" "22, 299" "System-DNS:" "53"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Dropbear:" "80" "WEB-Nginx:" "85"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSL:" "443" "SSL/PYTHON:" "443"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "80, 8080, 8880" "Squid:" "3128, 8000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "2082, 2086, 25" "BadVPN:" "7300"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "XRAY TLS:" "443" "XRAY NTLS:" "80, 8080, 8880"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SlowDNS:" "53" "Hysteria V1:" "20000-50000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "Hysteria V2:" "50001-60000" "" ""
  echo -e "${CYAN}----------------------- ${BOLD}SYSTEM RESOURCES${NC} ${CYAN}-----------------------${NC}"
  printf "  ${WHITE}%-10s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-10s${NC} ${YELLOW}%-10s${NC} ${WHITE}%-8s${NC} ${YELLOW}%s${NC}\n" "RAM Used:" "$ram" "CPU Used:" "$cpu" "Buffer:" "$buf"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] SSH Account Management (Legacy)"
  echo -e "  [${YELLOW}02${NC}] Xray Account Management (V2ray)"
  echo -e "  [${YELLOW}03${NC}] Hysteria (V1 & V2) Management"
  echo -e "  [${YELLOW}04${NC}] Monitor Active Connections"
  echo -e "  [${YELLOW}05${NC}] Service Controls (Restart Protocols)"
  echo -e "  [${YELLOW}06${NC}] Backup & Restore Data"
  echo -e "  [${YELLOW}07${NC}] System Utilities (BBR & Netflix)"
  echo -e "  [${YELLOW}08${NC}] Advanced Settings (Domain / Nameserver)"
  echo -e "  [${YELLOW}09${NC}] Reboot Server"
  echo -e "  [${RED}00${NC}] Exit\n"
  read -rp "  ► Select an option: " opt
  case "$opt" in
    1|01) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}SSH ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create SSH User\n  [${YELLOW}2${NC}] Extend User Expiry\n  [${YELLOW}3${NC}] Delete SSH User\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}XRAY ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Add Xray Account\n  [${YELLOW}2${NC}] Renew Xray Account\n  [${YELLOW}3${NC}] Delete Xray Account\n  [${YELLOW}4${NC}] Show Config Links\n  [${YELLOW}5${NC}] Force Delete Expired Xray Users Now\n  [${YELLOW}6${NC}] Update Xray Core Version\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_xray;; 2) renew_xray;; 3) del_xray;; 4) show_xray;; 5) /usr/local/bin/exp-check; echo "Expired Xray users wiped."; pause_return;; 6) systemctl stop xray; XRAY_VER="v26.5.9"; echo "Reinstalling Xray Core ${XRAY_VER}..."; wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"; unzip -q -o /tmp/xray.zip -d /tmp/xray/ && mv -f /tmp/xray/xray /usr/local/bin/xray; systemctl start xray; echo -e "${GREEN}✔ Xray Restored to ${XRAY_VER}!${NC}"; pause_return;; 0) break;; esac
      done ;;
    3|03)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                 ${BOLD}HYSTERIA (V1 & V2) MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  --- Hysteria V1 (Sing-Box) ---"
        echo -e "  [${YELLOW}1${NC}] Add V1 User\n  [${YELLOW}2${NC}] Renew V1 User\n  [${YELLOW}3${NC}] Delete V1 User\n  [${YELLOW}4${NC}] List V1 Accounts\n  [${YELLOW}5${NC}] Edit V1 Up/Down Speeds\n"
        echo -e "  --- Hysteria V2 (Native) ---"
        echo -e "  [${YELLOW}6${NC}] Add V2 User\n  [${YELLOW}7${NC}] Renew V2 User\n  [${YELLOW}8${NC}] Delete V2 User\n  [${YELLOW}9${NC}] List V2 Accounts\n"
        echo -e "  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub; case "$sub" in 1) add_hysteria_v1;; 2) extend_hysteria_v1;; 3) del_hysteria_v1;; 4) list_hysteria_v1;; 5) speed_hysteria_v1;; 6) add_hysteria_v2;; 7) extend_hysteria_v2;; 8) del_hysteria_v2;; 9) list_hysteria_v2;; 0) break;; esac
      done ;;
    4|04) online_users ;;
    5|05) service_control_menu ;;
    6|06)
      clear; echo -e "  [1] Backup System Configs\n  [2] Restore From Backup\n  [0] Back"
      read -rp " Select: " subopt; case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
    7|07) utilities_menu ;;
    8|08) advanced_menu ;;
    9|09) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

# Finishing
chown -R www-data:www-data /home/vps/public_html
clear
figlet GuruzGH Script -c | lolcat
echo "       Installation Complete! System need to reboot to apply all changes! "
history -c; rm /root/full.sh 2>/dev/null || true
echo "           Server will reboot in 10 seconds! "
sleep 10
reboot
