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

#Script Variables

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='299'

# Dropbear Ports
Dropbear_Port1='790'
Dropbear_Port2='550'

# Stunnel Ports
Stunnel_Port='443' # through SSLH

# Squid Ports
Squid_Port1='3128'
Squid_Port2='8000'

# Node.js Socks Proxy
WsPorts=('80' '8080' '8880' '25' '2082' '2086')  # WS ports to listen on
WsPort='80'  # default WS port for SSLH tracking

# SSLH Port
MainPort='666' # main port to tunnel default 443

# SSH SlowDNS
read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

# UDP HYSTERIA | UDP PORT | OBFS | PASSWORDS
UDP_PORT=":36712"

# Prompt installer for Hysteria obfs and password
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

######################################
###FreeNet AutoScript Code Begins...###
######################################

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

# Colours
red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'

# Requirement
apt-get update -y
apt-get upgrade -y --with-new-pkgs

# =========================================================
# Debian / Ubuntu compatibility detection
# =========================================================
if [ "${ID}" != "ubuntu" ] && [ "${ID}" != "debian" ]; then
  echo "This installer supports Debian and Ubuntu only. Detected: ${ID}"
  exit 1
fi

# Detect service names / paths safely
SSH_SERVICE="ssh"
DROPBEAR_SERVICE="dropbear"
STUNNEL_SERVICE="stunnel4"
SQUID_SERVICE="squid"
SSLH_SERVICE="sslh"
NGINX_SERVICE="nginx"

# Prefer internal-sftp for cross-distro compatibility
SFTP_SUBSYSTEM="internal-sftp"

# Make sure required directories exist
mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh

# Make sure OpenSSH host keys exist
ssh-keygen -A >/dev/null 2>&1 || true

# Ensure resolver file exists
touch /etc/resolv.conf

# Helpful compatibility fallbacks
command -v ss >/dev/null 2>&1 || apt-get install -y iproute2
command -v netfilter-persistent >/dev/null 2>&1 || apt-get install -y netfilter-persistent iptables-persistent
command -v jq >/dev/null 2>&1 || apt-get install -y jq
command -v curl >/dev/null 2>&1 || apt-get install -y curl

# stunnel service fallback
if ! systemctl list-unit-files | grep -q "^${STUNNEL_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^stunnel\.service"; then
    STUNNEL_SERVICE="stunnel"
  fi
fi

# squid service fallback
if ! systemctl list-unit-files | grep -q "^${SQUID_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^squid3\.service"; then
    SQUID_SERVICE="squid3"
  fi
fi

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx certbot jq figlet git gcc make build-essential perl expect libdbi-perl 
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    AVAILABLE_PACKAGES+=("$pkg")
  fi
done

# Disable IPV6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Add DNS server ipv4
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf

# Set System Time
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

# Login profile / banner
cat > /root/.profile <<'EOF_PROFILE'
# Guruz GH profile
clear
echo "Script By Guruz GH"
echo "Type 'menu' To List Commands"
EOF_PROFILE

# Installing some important machine essentials
apt-get install -y "${AVAILABLE_PACKAGES[@]}"

# Generate Dropbear keys only after dropbear package is installed
if command -v dropbearkey >/dev/null 2>&1; then
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  [ -f /etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  [ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

# Make sure base services exist on both Debian and Ubuntu
systemctl enable "$SSH_SERVICE" || true
systemctl enable rsyslog || true
systemctl restart rsyslog || true

# Installing a text colorizer and design
gem install lolcat

# purge if installed
apt -y --purge remove apache2 ufw firewalld

# Stop Nginx
systemctl stop nginx

# Download and install webmin
wget https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
sleep 1
rm -rf webmin_2.111_all.deb

# Use HTTP instead of HTTPS
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf

# Restart Webmin service
systemctl restart webmin || true
systemctl status --no-pager webmin || true

# Banner
cat <<'deekay77' > /etc/zorro-luffy
<br><img alt="TmzxboghrK0LzxE8Qp/qP6Enw++EHeVt" style="display:none;">
<font color="#C12267">GURUZGH | VPN | SERVICE<br></font>
<br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font>
<br>
<font color="red">• BROUGHT TO YOU BY <br></font><font color="#00cccc">https://t.me/guruzfreenet !<br></font>
deekay77

# Removing some duplicated sshd server configs
rm -f /etc/ssh/sshd_config

# Creating a SSH server config using cat eof tricks
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

sleep 2
# Now we'll put our ssh ports inside of sshd_config
sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config

sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password

sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells
echo '/usr/sbin/nologin' >> /etc/shells

# Restarting openssh service
systemctl restart "$SSH_SERVICE"
systemctl status --no-pager "$SSH_SERVICE"

# Removing some duplicate config file
rm -rf /etc/default/dropbear*
 
# Creating dropbear config using cat eof tricks
cat <<'MyDropbear' > /etc/default/dropbear
# Deekay Script Dropbear Config
NO_START=0
DROPBEAR_PORT=PORT01
DROPBEAR_EXTRA_ARGS="-p PORT02"
DROPBEAR_BANNER="/etc/zorro-luffy"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear

# Now changing our desired dropbear ports
sed -i "s|PORT01|$Dropbear_Port1|g" /etc/default/dropbear
sed -i "s|PORT02|$Dropbear_Port2|g" /etc/default/dropbear

# Restarting dropbear service
systemctl restart "$DROPBEAR_SERVICE"
systemctl status --no-pager "$DROPBEAR_SERVICE"

cd /etc/default/
[ -f sslh ] && cp -f sslh sslh-old || true
cat << sslh > /etc/default/sslh
RUN=yes

DAEMON=/usr/sbin/sslh

DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"

sslh

# Fix for sslh ubuntu
mkdir -p /var/run/sslh
touch /var/run/sslh/sslh.pid
chmod 777 /var/run/sslh/sslh.pid

# Restart service
systemctl daemon-reload
systemctl enable "$SSLH_SERVICE"
systemctl start "$SSLH_SERVICE"
systemctl restart "$SSLH_SERVICE"
systemctl status --no-pager "$SSLH_SERVICE"
cd

# Stunnel
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)

# Creating stunnel startup config using cat eof tricks
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/zorro-luffy"
PPP_RESTART=0
RLIMITS=""
MyStunnelD

# Removing all stunnel folder contents
rm -rf /etc/stunnel/*

# Creating stunnel server config
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

cat <<'MyStunnelCert' > /etc/stunnel/stunnel.pem
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
MyStunnelCert

# Setting stunnel ports
sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf

# Restarting stunnel service
systemctl restart "$STUNNEL_SERVICE"
systemctl enable "$STUNNEL_SERVICE"
systemctl status --no-pager "$STUNNEL_SERVICE"

# Setting Up Socks (Node.js All-in-One Proxy)
loc=/etc/socksproxy
mkdir -p $loc

# Ensure Node.js is installed
apt-get install -y nodejs

# Convert the bash WsPorts array into a comma-separated JavaScript array format
JS_PORTS="[${WsPorts[*]}]"
JS_PORTS="${JS_PORTS// /, }"

# Create the fixed Node.js proxy script
cat <<EOF > $loc/proxy.js
const net = require('net');

// Catch unhandled errors so a single bad connection doesn't crash the whole proxy
process.on('uncaughtException', (err) => {
    console.error('Unhandled Exception:', err);
});

const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = $Dropbear_Port1; 
const LISTEN_PORTS = $JS_PORTS;

const handleConnection = (clientSocket) => {
    // Read ONLY the very first chunk of data (the HTTP Request payload)
    clientSocket.once('data', (data) => {
        
        // Connect to Dropbear locally
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            
            // We DO NOT forward the initial HTTP payload to Dropbear! 
            // We eat it, and immediately send back the "101 Switching Protocols"
            // response that the VPN client expects. This mimics the Python script behavior.
            clientSocket.write('HTTP/1.1 101 Switching Protocols\r\n\r\n');
            
            // Once the 101 response is sent, we pipe the streams. 
            // Dropbear will now send its SSH banner, and the SSH handshake begins safely.
            clientSocket.pipe(targetSocket);
            targetSocket.pipe(clientSocket);
        });

        // Error handling to tear down safely
        targetSocket.on('error', () => clientSocket.destroy());
        targetSocket.on('close', () => clientSocket.destroy());
    });

    clientSocket.on('error', () => {});
    clientSocket.on('close', () => {});
};

// Start a listener for every port defined in your array
LISTEN_PORTS.forEach((port) => {
    const server = net.createServer(handleConnection);
    server.listen(port, '0.0.0.0', () => {
        console.log(\`WS Proxy active on port \${port} -> mapping to Dropbear on \${TARGET_PORT}\`);
    });
});
EOF

# Create a single systemd service to manage all WebSocket ports
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

# Start the Node WS Proxy
systemctl daemon-reload
systemctl enable ws-proxy
systemctl start ws-proxy
systemctl status --no-pager ws-proxy || true

# Nginx configure
rm /home/vps/public_html -rf
rm /etc/nginx/sites-* -rf
rm /etc/nginx/nginx.conf -rf
sleep 1
mkdir -p /home/vps/public_html

# Creating nginx config for our webserver
cat <<'myNginxC' > /etc/nginx/nginx.conf

user www-data;

worker_processes auto;
pid /var/run/nginx.pid;

events {
	multi_accept on;
  worker_connections 8192;
}

http {
	gzip on;
	gzip_vary on;
	gzip_comp_level 5;
	gzip_types    text/plain application/x-javascript text/xml text/css;

	autoindex on;
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  server_tokens off;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log;
  client_max_body_size 32M;
	client_header_buffer_size 8m;
	large_client_header_buffers 8 8m;

	fastcgi_buffer_size 8m;
	fastcgi_buffers 8 8m;

	fastcgi_read_timeout 600;


  include /etc/nginx/conf.d/*.conf;
}
myNginxC

# Creating vps config for our OCS Panel
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server {
  listen       Nginx_Port;
  server_name  127.0.0.1 localhost;
  access_log /var/log/nginx/vps-access.log;
  error_log /var/log/nginx/vps-error.log error;
  root   /home/vps/public_html;

  location / {
    index  index.html index.htm index.php;
    try_files $uri $uri/ /index.php?$args;
  }
}
myvpsC

# Setting up our WebServer Ports and IP Addresses
cd
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf

# Restarting nginx
systemctl restart "$NGINX_SERVICE"
systemctl status --no-pager "$NGINX_SERVICE"

# Removing Duplicate Squid config
rm -rf /etc/squid/squid.con*
 
# Creating Squid server config using cat eof tricks
cat <<'mySquid' > /etc/squid/squid.conf
# My Squid Proxy Server Config
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

# Setting machine's IP Address inside of our Squid config(security that only allows this machine to use this proxy server)
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf
 
# Setting squid ports
sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf
sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf

# Starting Proxy server
echo -e "Restarting Squid Proxy server..."
systemctl restart "$SQUID_SERVICE"
systemctl status --no-pager "$SQUID_SERVICE"

# Make a folder
mkdir -p /etc/deekayvpn

# Cronjob script for auto restart services
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash

MYID="MYCHATID"
KEY="MYBOTID"
URL="https://api.telegram.org/bot${KEY}/sendMessage"

send_telegram_message() {
    local TEXT="$1"
    curl -s --max-time 10 --retry 5 --retry-delay 2 --retry-max-time 10 \
      -d "chat_id=${MYID}&text=${TEXT}&disable_web_page_preview=true&parse_mode=markdown" \
      "${URL}" >/dev/null 2>&1
}

server_ip="IPADDRESS"
datenow=$(date +"%Y-%m-%d %T")
IPCOUNTRY=$(curl -s "https://freeipapi.com/api/json/${server_ip}" | jq -r '.countryName')

STATE_DIR="/etc/deekayvpn/health"
mkdir -p "$STATE_DIR"

check_port() {
    local port="$1"
    ss -lnt | awk '{print $4}' | grep -q ":${port}$"
}

mark_fail() {
    local name="$1"
    local f="$STATE_DIR/${name}.fail"
    local n=0
    [ -f "$f" ] && n=$(cat "$f")
    n=$((n+1))
    echo "$n" > "$f"
    echo "$n"
}

clear_fail() {
    local name="$1"
    rm -f "$STATE_DIR/${name}.fail"
}

restart_after_3_fails() {
    local name="$1"
    local unit="$2"
    local ports="$3"

    local fails
    fails=$(mark_fail "$name")

    if [ "$fails" -ge 3 ]; then
        systemctl restart "$unit" >/dev/null 2>&1
        TEXT="Service *$unit* was offline or missing port(s) *$ports* on server *${IPCOUNTRY}* ($server_ip). It has been restarted at *${datenow}*."
        send_telegram_message "$TEXT"
        clear_fail "$name"
    fi
}

# dropbear
if check_port DROPBEARPORT1 && check_port DROPBEARPORT2 && systemctl is-active --quiet dropbear; then
    clear_fail dropbear
else
    restart_after_3_fails dropbear dropbear "DROPBEARPORT1,DROPBEARPORT2"
fi

# stunnel
if check_port STUNNELPORT && systemctl is-active --quiet stunnel4; then
    clear_fail stunnel4
else
    restart_after_3_fails stunnel4 stunnel4 "STUNNELPORT"
fi

# sslh
if check_port SSLHPORT && systemctl is-active --quiet sslh; then
    clear_fail sslh
else
    restart_after_3_fails sslh sslh "SSLHPORT"
fi

# squid
if check_port SQUIDPORT1 && check_port SQUIDPORT2 && systemctl is-active --quiet squid; then
    clear_fail squid
else
    restart_after_3_fails squid squid "SQUIDPORT1,SQUIDPORT2"
fi

# nginx
if check_port NGINXPORT && systemctl is-active --quiet nginx; then
    clear_fail nginx
else
    restart_after_3_fails nginx nginx "NGINXPORT"
fi

# ssh
if check_port SSHPORT1 && check_port SSHPORT2 && systemctl is-active --quiet ssh; then
    clear_fail ssh
else
    restart_after_3_fails ssh ssh "SSHPORT1,SSHPORT2"
fi

# WS: Node.js All-in-One Proxy
# Do not auto-restart the websocket unit from the health checker,
# because restarting it disconnects all active VPN users across all ports.
for port in WS_PORT_LIST; do
    if check_port "$port" && systemctl is-active --quiet ws-proxy; then
        clear_fail "ws_${port}"
    else
        mark_fail "ws_${port}" >/dev/null
        # intentionally no restart here
    fi
done
ServiceChecker

chmod 755 /etc/deekayvpn/service_checker.sh
WS_PORT_LIST="${WsPorts[*]}"
sed -i "s|WS_PORT_LIST|$WS_PORT_LIST|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT1|$Dropbear_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|DROPBEARPORT2|$Dropbear_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|STUNNELPORT|$Stunnel_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh

# Webmin Configuration
sed -i '$ i\deekay: acl adsl-client ajaxterm apache at backup-config bacula-backup bandwidth bind8 burner change-user cluster-copy cluster-cron cluster-passwd cluster-shell cluster-software cluster-useradmin cluster-usermin cluster-webmin cpan cron custom dfsadmin dhcpd dovecot exim exports fail2ban fdisk fetchmail file filemin filter firewall firewalld fsdump grub heartbeat htaccess-htpasswd idmapd inetd init inittab ipfilter ipfw ipsec iscsi-client iscsi-server iscsi-target iscsi-tgtd jabber krb5 ldap-client ldap-server ldap-useradmin logrotate lpadmin lvm mailboxes mailcap man mon mount mysql net nis openslp package-updates pam pap passwd phpini postfix postgresql ppp-client pptp-client pptp-server proc procmail proftpd qmailadmin quota raid samba sarg sendmail servers shell shorewall shorewall6 smart-status smf software spam squid sshd status stunnel syslog-ng syslog system-status tcpwrappers telnet time tunnel updown useradmin usermin vgetty webalizer webmin webmincron webminlog wuftpd xinetd' /etc/webmin/webmin.acl
sed -i '$ i\deekay:0' /etc/webmin/miniserv.users
/usr/share/webmin/changepass.pl /etc/webmin deekay 20037

# Some Settings
sed -i "s|#SystemMaxUse=|SystemMaxUse=10M|g" /etc/systemd/journald.conf
sed -i "s|#SystemMaxFileSize=|SystemMaxFileSize=1M|g" /etc/systemd/journald.conf
systemctl restart systemd-journald


# High-concurrency tuning for Debian/Ubuntu
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
SYSCTL
sysctl --system || true

mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# Log Settings
rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog
{
        daily
        missingok
        notifempty
        create 640 syslog adm
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}

/var/log/kern.log
/var/log/auth.log
{
        rotate 1
        daily
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                /usr/lib/rsyslog/rsyslog-rotate
        endscript
}
logrotate
chown root:root /var/log
chmod 755 /var/log
chown root:root /var/log
chown syslog:adm /var/log/syslog
chmod 640 /var/log/syslog
logrotate -v -f /etc/logrotate.d/rsyslog

# CONFIGURE SLOWDNS
rm -rf /etc/slowdns
mkdir -m 777 /etc/slowdns
# ServerKEY
cat > /etc/slowdns/server.key << END
$Serverkey
END
# ServerPUB
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key
chmod +x /etc/slowdns/server.pub
chmod +x /etc/slowdns/sldns-server

# Iptables Rule for SlowDNS server new implementation
iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

# Install server-sldns.service
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS By Guruz GH 
Documentation=https://techguruzgh.com
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

# Permission service slowdns
cd
chmod +x /etc/systemd/system/server-sldns.service
pkill sldns-server
systemctl daemon-reload
systemctl stop server-sldns
systemctl enable server-sldns
systemctl start server-sldns
systemctl restart server-sldns
systemctl status --no-pager server-sldns

# UDP hysteria
wget -N --no-check-certificate -q -O ~/install_server.sh https://raw.githubusercontent.com/RepositoriesDexter/Hysteria/main/install_server.sh; chmod +x ~/install_server.sh; ./install_server.sh --version v1.3.5
rm -f /etc/hysteria/config.json

# Ensure /etc/hysteria exists
mkdir -p /etc/hysteria

# Derive numeric port from UDP_PORT (accepts formats like ":36712" or "0.0.0.0:36712")
HYST_PORT="${UDP_PORT##*:}"

# Create the hysteria config with proper variable expansion
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
  "auth": {
    "mode": "passwords",
    "config": ["$PASSWORD"]
  }
}
EOF

# Creating Hysteria CERT
cat << EOF > /etc/hysteria/hysteria.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            40:26:da:91:18:2b:77:9c:85:6a:0c:bb:ca:90:53:fe
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
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Subject Key Identifier: 
                6B:08:C0:64:10:71:A8:32:7F:0B:FE:1E:98:1F:BD:72:74:0F:C8:66
            X509v3 Authority Key Identifier: 
                keyid:64:49:32:6F:FE:66:62:F1:57:4D:BB:91:A8:5D:BD:26:3E:51:A4:D2
                DirName:/CN=KobZ
                serial:01:A4:01:02:93:12:D9:D6:01:A9:83:DC:03:73:DA:ED:C8:E3:C3:B7
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: 
                DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         a1:3e:ac:83:0b:e5:5d:ca:36:b7:d0:ab:d0:d9:73:66:d1:62:
         88:ce:3d:47:9e:08:0b:a0:5b:51:13:fc:7e:d7:6e:17:0e:bd:
         f5:d9:a9:d9:06:78:52:88:5a:e5:df:d3:32:22:4a:4b:08:6f:
         b1:22:80:4f:19:d1:5f:9d:b6:5a:17:f7:ad:70:a9:04:00:ff:
         fe:84:aa:e1:cb:0e:74:c0:1a:75:0b:3e:98:90:1d:22:ba:a4:
         7a:26:65:7d:d1:3b:5c:45:a1:77:22:ed:b6:6b:18:a3:c4:ee:
         3e:06:bb:0b:ec:12:ac:16:a5:50:b3:ed:46:43:87:72:fd:75:
         8c:38
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

chmod 755 /etc/hysteria/config.json
chmod 755 /etc/hysteria/hysteria.crt
chmod 755 /etc/hysteria/hysteria.key

# Add iptables NAT rule - use detected interface and the derived hysteria port
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
iptables -C INPUT -p udp --dport "$HYST_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST_PORT" -j ACCEPT
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || \
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT

# Boot-persistent Hysteria NAT restore
cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore Hysteria UDP NAT rule
After=network-online.target
Wants=network-online.target
Before=hysteria-server.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\S+)"|head -1); [ -n "$IFACE" ] && (iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria-nat.service
systemctl start hysteria-nat.service
systemctl enable hysteria-server.service
systemctl restart hysteria-server.service
systemctl status --no-pager hysteria-server.service

# Creating startup 1 script using cat eof tricks
cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh

# Setting server local time
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime

# Prevent DOS-like UI when installing using APT (Disabling APT interactive dialog)
export DEBIAN_FRONTEND=noninteractive

# Allowing SlowDNS to Forward traffic
iptables -C INPUT -p udp --dport 5300 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300 2>/dev/null || iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

# Disable IpV6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

# Add DNS server ipv4
echo "nameserver DNS1" > /etc/resolv.conf
echo "nameserver DNS2" >> /etc/resolv.conf

# For sslh
mkdir -p /var/run/sslh
touch /var/run/sslh/sslh.pid
chmod 777 /var/run/sslh/sslh.pid

# For udp
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712

deekayz

sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup
#rm -rf /etc/sysctl.d/99*

 # Setting our startup script to run every machine boots 
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

chmod +x /etc/deekaystartup
systemctl enable deekaystartup
systemctl start deekaystartup
systemctl status --no-pager deekaystartup
netfilter-persistent save || true
cd

# Pull BadVPN Binary 64bit or 32bit
if [ "$(getconf LONG_BIT)" == "64" ]; then
 wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
 wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi

# Change Permission to make it Executable
chmod +x /usr/bin/badvpn-udpgw
 
# Setting our startup script for badvpn
cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10

[Install]
WantedBy=multi-user.target
deekayb

systemctl enable badvpn
systemctl start badvpn
systemctl status --no-pager badvpn

# Some Final Cronjob
echo "* * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker
echo "*/2 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate

clear
cd
echo " "
echo " "
echo "PREMIUM SCRIPT SUCCESSFULLY INSTALLED!"
echo "SCRIPT BY GURUZ GH"
echo "PLEASE WAIT..."
echo " "

# Install bundled Guruz GH menu
cd /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash

# Modern Color Palette
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Utility Functions ---

server_ip() {
  local ip
  ip=$(curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null)
  [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  [ -z "$ip" ] && ip="Unavailable"
  echo "$ip"
}

cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh dropbear stunnel4 squid nginx server-sldns hysteria-server ws-proxy; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}ONLINE${NC}" || echo -e "${RED}ISSUES DETECTED${NC}"
}

pause_return() {
  echo
  read -rp "Press ENTER to return... " _
}

list_real_users() {
  awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "systemd-timesync" && $1 != "polkitd" && $1 != "debian-tor" && $1 != "messagebus" && $1 != "redis" {print $1}' /etc/passwd 2>/dev/null
}

select_user() {
  local purpose="$1"
  mapfile -t USERS < <(list_real_users)
  if [ "${#USERS[@]}" -eq 0 ]; then
    echo -e "${RED}No active user accounts found.${NC}"
    return 1
  fi

  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!USERS[@]}"; do
    printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${USERS[$i]}"
  done
  echo
  echo -e "  [${YELLOW}00${NC}] Back"
  echo
  read -rp "  Select an account number: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return 1
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}" ]; then
    echo -e "${RED}  Invalid selection.${NC}"
    return 1
  fi
  SELECTED_USER="${USERS[$((idx-1))]}"
  return 0
}

# --- Core Logic Functions ---

create_user() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREATE NEW SSH USER${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Username: " user
  read -rp "  Password: " pass
  read -rp "  Valid for (days): " days

  if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$days" ]; then
    echo -e "\n${RED}  Error: All fields are required.${NC}"
    pause_return; return
  fi

  if id "$user" >/dev/null 2>&1; then
    echo -e "\n${RED}  Error: User '$user' already exists.${NC}"
    pause_return; return
  fi

  useradd -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" && \
  echo "$user:$pass" | chpasswd

  IP=$(curl -s ipv4.icanhazip.com)
  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}ACCOUNT CREATED SUCCESSFULLY${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}IP Address${NC} : ${YELLOW}$IP${NC}"
  echo -e "  ${BOLD}Username${NC}   : ${YELLOW}$user${NC}"
  echo -e "  ${BOLD}Password${NC}   : ${YELLOW}$pass${NC}"
  echo -e "  ${BOLD}Expiry${NC}     : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  SSH Port   : 22, 299"
  echo -e "  Dropbear   : 790, 550"
  echo -e "  SSL/TLS    : 443"
  echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086, 25"
  echo -e "  SlowDNS    : 5300"
  echo -e "  BadVPN     : 7300"
  echo -e "  Hysteria   : 20000-50000"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "DELETE SSH USER"; then pause_return; return; fi
  clear
  echo -e "${RED}Warning: You are about to delete user: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Are you sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    userdel -r "$SELECTED_USER" 2>/dev/null || userdel "$SELECTED_USER" 2>/dev/null
    echo -e "${GREEN}User $SELECTED_USER has been deleted.${NC}"
  else
    echo -e "Deletion cancelled."
  fi
  pause_return
}

extend_user() {
  if ! select_user "EXTEND USER EXPIRY"; then pause_return; return; fi
  clear
  echo -e "Extending account for: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Enter number of days to add: " days
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Invalid number format.${NC}"
    pause_return; return
  fi
  
  current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
  if [ "$current" = "never" ] || [ -z "$current" ]; then
    new_exp=$(date -d "+$days days" +%Y-%m-%d)
  else
    new_exp=$(date -d "$current +$days days" +%Y-%m-%d)
  fi
  
  chage -E "$new_exp" "$SELECTED_USER"
  echo -e "${GREEN}Success!${NC} Account extended."
  echo -e "New Expiry Date: ${YELLOW}$new_exp${NC}"
  pause_return
}

online_users() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "               ${BOLD}ACTIVE USER SESSIONS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

  declare -A ssh_count dropbear_count total_count
  
  # 1. Parse OpenSSH (sshd) Users
  while IFS= read -r user; do
    if [ -n "$user" ] && [ "$user" != "root" ] && id "$user" >/dev/null 2>&1; then
      # Separate the math to avoid Bash syntax errors
      s_val=${ssh_count["$user"]:-0}
      ssh_count["$user"]=$((s_val + 1))
      
      t_val=${total_count["$user"]:-0}
      total_count["$user"]=$((t_val + 1))
    fi
  done < <(ps -eo args 2>/dev/null | grep "^sshd: " | grep -v "listener" | awk '{print $2}' | cut -d'@' -f1)

  # 2. Parse Dropbear & WebSocket Users
  active_dropbear_pids=$(ps -ef | grep "[d]ropbear" | awk '{print $2}')
  
  for pid in $active_dropbear_pids; do
    # Try reading from auth.log first
    user=$(grep "dropbear\[$pid\]" /var/log/auth.log 2>/dev/null | grep -i "succeeded" | tail -1 | awk -F"'" '{print $2}')
    
    # Fallback to journalctl if auth.log rotated
    if [ -z "$user" ]; then
      user=$(journalctl -u dropbear --no-pager 2>/dev/null | grep "dropbear\[$pid\]" | grep -i "succeeded" | tail -1 | awk -F"'" '{print $2}')
    fi
    
    if [ -n "$user" ] && [ "$user" != "root" ] && id "$user" >/dev/null 2>&1; then
      # Separate the math to avoid Bash syntax errors
      d_val=${dropbear_count["$user"]:-0}
      dropbear_count["$user"]=$((d_val + 1))
      
      t_val=${total_count["$user"]:-0}
      total_count["$user"]=$((t_val + 1))
    fi
  done

  if [ "${#total_count[@]}" -eq 0 ]; then
    echo -e "${YELLOW}  No authenticated users are currently online.${NC}\n"
    pause_return
    return
  fi

  printf "  %-20s %-10s %-12s %-8s\n" "USERNAME" "SSH" "DROPBEAR" "TOTAL"
  echo -e "${CYAN}  ----------------------------------------------------------${NC}"

  for user in "${!total_count[@]}"; do
    # Extract values cleanly
    s_count=${ssh_count["$user"]:-0}
    d_count=${dropbear_count["$user"]:-0}
    t_count=${total_count["$user"]:-0}
    
    printf "  %-20s %-10s %-12s %-8s\n" "$user" "$s_count" "$d_count" "$t_count"
  done | sort

  echo
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
    echo -e "  [${YELLOW}03${NC}] Restart Node WebSocket Proxy"
    echo -e "  [${YELLOW}04${NC}] Restart Stunnel (SSL)"
    echo -e "  [${YELLOW}05${NC}] Restart Squid Proxy & Nginx"
    echo -e "  [${YELLOW}06${NC}] Restart UDP Core (SlowDNS / Hysteria / BadVPN)"
    echo -e "  [${YELLOW}00${NC}] Back"
    echo
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) 
        restart_service "ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy" "All Services"
        pause_return ;;
      2|02) restart_service "ssh dropbear" "SSH & Dropbear"; pause_return ;;
      3|03) restart_service "ws-proxy" "Node WebSocket Proxy"; pause_return ;;
      4|04) restart_service "stunnel4" "Stunnel (SSL)"; pause_return ;;
      5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
      6|06) restart_service "server-sldns hysteria-server badvpn" "UDP Core Services"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Backup & Restore ---

backup_snapshot() {
  clear
  local out="/root/guruzgh_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo -e "Packaging server configurations..."
  tar -czf "$out" /etc/ssh /etc/default/dropbear /etc/stunnel /etc/squid /etc/hysteria /etc/deekayvpn /etc/systemd/system/ws-proxy.service 2>/dev/null
  echo -e "\n${GREEN}✔ Backup successfully created!${NC}"
  echo -e "Location: ${YELLOW}$out${NC}"
  pause_return
}

restore_snapshot() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RESTORE CONFIGURATION${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  shopt -s nullglob
  backups=(/root/guruzgh_backup_*.tar.gz /root/guruzgh_snapshot_*.tar.gz)
  if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}  No backup files found in /root/.${NC}"
    pause_return; return
  fi
  
  echo -e "  Available Backups:\n"
  for i in "${!backups[@]}"; do
    printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"
  done
  echo
  echo -e "  [${YELLOW}00${NC}] Cancel"
  echo
  read -rp "  Select backup to restore: " sel
  if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
  
  idx=$((sel-1))
  if [ -n "${backups[$idx]}" ]; then
    echo -e "\nRestoring ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
    tar -xzf "${backups[$idx]}" -C /
    echo -e "Reloading configurations and restarting services..."
    systemctl daemon-reload
    systemctl restart ssh dropbear stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy 2>/dev/null || true
    echo -e "${GREEN}✔ Restore complete!${NC}"
  else
    echo -e "${RED}Invalid selection.${NC}"
  fi
  pause_return
}


# --- Advanced / Danger Zone ---

advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}ADVANCED SETTINGS${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] Backup Server Configuration"
    echo -e "  [${YELLOW}02${NC}] Restore Server Configuration"
    echo -e "  [${YELLOW}03${NC}] View Raw Hysteria JSON"
    echo -e "  [${YELLOW}04${NC}] View Service Action Logs (Journalctl)"
    echo -e "  [${RED}05${NC}] Full Script Uninstall (Danger)"
    echo -e "  [${YELLOW}00${NC}] Back"
    echo
    read -rp "  Select an option: " opt
    case "$opt" in
      1|01) backup_snapshot ;;
      2|02) restore_snapshot ;;
      3|03) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "Not found."; pause_return ;;
      4|04) 
        clear; echo -e "[1] SSH  [2] WS-Proxy  [3] Hysteria  [4] Stunnel  [5] SlowDNS\n"
        read -rp "Select log: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy -n 50 --no-pager ;;
          3) journalctl -u hysteria-server -n 50 --no-pager ;;
          4) journalctl -u stunnel4 -n 50 --no-pager ;;
          5) journalctl -u server-sldns -n 50 --no-pager ;;
        esac
        pause_return ;;
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
  echo -e "  This action will strip all custom VPN services, configurations,"
  echo -e "  and scripts installed by Guruz GH from your server.\n"
  read -rp "  Are you absolutely sure? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo -e "\nStopping services..."
      systemctl stop ws-proxy server-sldns deekaystartup badvpn hysteria-server sslh stunnel4 squid dropbear nginx 2>/dev/null || true
      systemctl disable ws-proxy server-sldns deekaystartup badvpn hysteria-server 2>/dev/null || true
      echo "Deleting files..."
      rm -f /etc/systemd/system/ws-proxy.service /etc/systemd/system/server-sldns.service /etc/systemd/system/deekaystartup.service /etc/systemd/system/badvpn.service
      rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
      rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
      systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
      echo -e "${GREEN}✔ Removal complete.${NC}"
  else
      echo "Cancelled."
  fi
  pause_return
}

# --- Main Dashboard & UI ---

draw_header() {
  IFS='|' read -r TOTAL FREE USED <<< "$(mem_stats)"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}Guruz GH${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Plus${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo
  echo -e "  ${WHITE}OS:${NC} ${YELLOW}$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')${NC}   ${WHITE}Arch:${NC} ${YELLOW}$(uname -m)${NC}   ${WHITE}Cores:${NC} ${YELLOW}$(cpu_count)${NC}"
  echo -e "  ${WHITE}IP:${NC} ${YELLOW}$(server_ip)${NC}   ${WHITE}Time:${NC} ${YELLOW}$(date '+%H:%M %Z')${NC}   ${WHITE}Status:${NC} $(server_status)"
  echo
  echo -e "${CYAN}------------------------ ${BOLD}PROTOCOL PORTS${NC} ${CYAN}------------------------${NC}"
  echo -e "  ${WHITE}SSH:${NC} ${GREEN}22, 299${NC}                   ${WHITE}System-DNS:${NC} ${GREEN}53${NC}"
  echo -e "  ${WHITE}Dropbear:${NC} ${GREEN}790, 550${NC}             ${WHITE}WEB-Nginx:${NC} ${GREEN}85${NC}"
  echo -e "  ${WHITE}SSL/TLS:${NC} ${GREEN}443${NC}                   ${WHITE}Squid Proxy:${NC} ${GREEN}8000, 3128${NC}"
  echo -e "  ${WHITE}WS/Node:${NC} ${GREEN}80, 8080, 8880${NC}        ${WHITE}SlowDNS:${NC} ${GREEN}5300${NC}"
  echo -e "  ${WHITE}WS/Node:${NC} ${GREEN}25, 2082, 2086${NC}        ${WHITE}HysteriaUDP:${NC} ${GREEN}20k-50k${NC}"
  echo -e "${CYAN}----------------------- ${BOLD}SYSTEM RESOURCES${NC} ${CYAN}-----------------------${NC}"
  echo -e "  ${WHITE}RAM Used:${NC} ${YELLOW}$(ram_percent)${NC}   ${WHITE}CPU Used:${NC} ${YELLOW}$(cpu_percent)${NC}   ${WHITE}Buffer:${NC} ${YELLOW}$(buffer_mem)${NC}"
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
  echo -e "  [${RED}00${NC}] Exit"
  echo
  read -rp "  ► Select an option: " opt
  case "$opt" in
    1|01)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}ACCOUNT MANAGEMENT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Create SSH User\n  [${YELLOW}2${NC}] Extend User Expiry\n  [${YELLOW}3${NC}] Delete SSH User\n  [${YELLOW}4${NC}] List All Accounts\n  [${YELLOW}0${NC}] Back\n"
        read -rp "  ► Option: " sub_opt
        case "$sub_opt" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02) online_users ;;
    3|03) service_control_menu ;;
    4|04) advanced_menu ;;
    5|05) clear; read -rp "Reboot server now? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    0|00) clear; exit 0 ;;
    *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
  esac
done
EOF_MENU
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu
chmod +x /usr/bin/Menu
chmod +x /usr/bin/menu
cd

# Finishing
chown -R www-data:www-data /home/vps/public_html

clear
echo ""
echo " INSTALLATION FINISH! "
echo ""
echo ""
echo "Server Information: " | tee -a log-install.txt | lolcat
echo "   • Timezone       : $MyVPS_Time "  | tee -a log-install.txt | lolcat
echo "   • IPtables       : [ON]"  | tee -a log-install.txt | lolcat
echo "   • Auto-Reboot    : [OFF] See menu to [ON] "  | tee -a log-install.txt | lolcat

echo " "| tee -a log-install.txt | lolcat
echo "Automated Features:"| tee -a log-install.txt | lolcat
echo "   • Auto restart server "| tee -a log-install.txt | lolcat
echo "   • Auto disconnect multilogin users [Openvpn]."| tee -a log-install.txt | lolcat
echo "   • Auto configure firewall every reboot[Protection for torrent and etc..]"| tee -a log-install.txt | lolcat
echo "   • Debian/Ubuntu compatibility improvements applied"| tee -a log-install.txt | lolcat
echo "   • High-concurrency tuning enabled for larger user counts"| tee -a log-install.txt | lolcat

echo " " | tee -a log-install.txt | lolcat
echo "Services & Port Information:" | tee -a log-install.txt | lolcat
echo "   • Dropbear             : [ON] : $Dropbear_Port1 | $Dropbear_Port2 " | tee -a log-install.txt | lolcat
echo "   • Squid Proxy          : [ON] : $Squid_Port1 | $Squid_Port2" | tee -a log-install.txt | lolcat
echo "   • SSL through Dropbear : [ON] : 443" | tee -a log-install.txt | lolcat
echo "   • SSH Websocket Node   : [ON] : 80 | 8080 | 8880 | 2082 | 2086 | 25" | tee -a log-install.txt | lolcat
echo "   • BadVPN               : [ON] : 7300 " | tee -a log-install.txt | lolcat
echo "   • Hysteria             : [ON] : 20000:50000" | tee -a log-install.txt | lolcat
echo "   • Nginx                : [ON] : $Nginx_Port" | tee -a log-install.txt | lolcat

echo "" | tee -a log-install.txt | lolcat
echo "Notes:" | tee -a log-install.txt | lolcat
echo "  ★ To display list of commands:  " [ menu ] or [ menu dk ] "" | tee -a log-install.txt | lolcat
echo "" | tee -a log-install.txt | lolcat
echo "  ★ Other concern and questions of these auto-scripts?" | tee -a log-install.txt | lolcat
echo "    Direct Messege : https://t.me/guruzgh" | tee -a log-install.txt | lolcat
echo ""

echo ""
echo "==================== PORTS SUMMARY (Post-Install) ====================" | tee -a log-install.txt
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a log-install.txt
echo "" | tee -a log-install.txt

echo "[1/4] Systemd services (WS instances)" | tee -a log-install.txt
systemctl is-active ws-proxy >/dev/null 2>&1 && \
  echo "  ws-proxy: active (Ports: ${WsPorts[*]})" | tee -a log-install.txt || \
  echo "  ws-proxy: NOT active (check: journalctl -u ws-proxy -n 50 --no-pager)" | tee -a log-install.txt
echo "" | tee -a log-install.txt

echo "[2/4] Listening sockets (TCP/UDP) - filtered" | tee -a log-install.txt
# Show listeners for the main ports used by this script
ss -lntup 2>/dev/null | egrep -n ':(22|80|85|299|443|550|666|790|3128|8000|8080|8880|2082|2086|25|5300|7300|36712)\b' | tee -a log-install.txt || true
echo "" | tee -a log-install.txt

echo "[3/4] NAT/Firewall rules (iptables -t nat) - relevant lines" | tee -a log-install.txt
iptables -t nat -S 2>/dev/null | egrep -n '(REDIRECT|DNAT|--dport 53|5300|36712|20000:50000|--dport 443|--dport 80|--dport 85|--dport 8080|--dport 8880|--dport 2052|--dport 2082|--dport 2086|--dport 2095|--dport 25)' | tee -a log-install.txt || true
echo "" | tee -a log-install.txt

echo "[4/4] Config quick-checks" | tee -a log-install.txt
echo "  Squid listen ports:" | tee -a log-install.txt
grep -nE '^\s*http_port\s+' /etc/squid/squid.conf 2>/dev/null | tee -a log-install.txt || true
echo "  Nginx listen ports:" | tee -a log-install.txt
grep -nE '^\s*listen\s+' /etc/nginx/conf.d/vps.conf 2>/dev/null | tee -a log-install.txt || true
echo "  Stunnel accept ports:" | tee -a log-install.txt
grep -nE '^\s*accept\s*=' /etc/stunnel/stunnel.conf 2>/dev/null | tee -a log-install.txt || true
echo "======================================================================" | tee -a log-install.txt
echo "" | tee -a log-install.txt

clear
echo ""
echo ""
figlet GuruzGH Script -c | lolcat
echo ""
echo "       Installation Complete! System need to reboot to apply all changes! "
history -c;
rm /root/full.sh
echo "           Server will secure this server and reboot after 10 seconds! "
sleep 10
reboot
