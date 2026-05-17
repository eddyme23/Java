#!/bin/bash
set -o pipefail

#by GuruzGH
clear

# Initializing Server
export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|debian:11|debian:12|debian:13) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12/13 only."
  exit 1
fi

#Script Variables
read -p "Enter your Domain/Subdomain for Xray (or press enter for IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

SSH_Port1='22'; SSH_Port2='299'
Dropbear_Port1='790'; Dropbear_Port2='550'
Stunnel_Port='127.0.0.1:4443'; Stunnel_Port_Num='4443' 
Squid_Port1='3128'; Squid_Port2='8000'
WsPorts=('10080' '25' '2082' '2086'); WsPort='10080'  
MainPort='666' 
OVPN_Port='1194'
SS_Port='8388'

read -p "Enter SlowDNS Nameserver (or press enter for default): " -e -i "ns-dl.guruzgh.ovh" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

UDP_PORT=":36712" # HY1
UDP_PORT2=":36713" # HY2
_default_obfs='GuruzScript'
_default_password='GuruzScript'

if [ -t 0 ]; then
  read -e -p "Enter Hysteria obfuscation string (obfs) [${_default_obfs}]: " -i "${_default_obfs}" OBFS
  read -e -p "Enter Default Hysteria password [${_default_password}]: " -i "${_default_password}" PASSWORD
else
  OBFS="${_default_obfs}"; PASSWORD="${_default_password}"
fi
export OBFS PASSWORD

Nginx_Port='85' 
Dns_1='1.1.1.1'; Dns_2='1.0.0.1'
MyVPS_Time='Africa/Accra'
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

apt-get update -y && apt-get upgrade -y --with-new-pkgs
systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null

SSH_SERVICE="ssh"; DROPBEAR_SERVICE="dropbear"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray /etc/openvpn/server
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps openvpn easy-rsa
)
apt-get install -y "${PACKAGE_LIST[@]}"

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "Script By Guruz GH"
echo "Type 'menu' To List Commands"
EOF_PROFILE

if command -v dropbearkey >/dev/null 2>&1; then
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  [ -f /etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  [ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

systemctl enable "$SSH_SERVICE" rsyslog || true
systemctl restart rsyslog || true
gem install lolcat
apt -y --purge remove apache2 ufw firewalld
systemctl stop nginx

# === OPENVPN (TCP 1194 with PAM Auth) ===
echo "Configuring OpenVPN..."
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa --batch build-server-full server nopass
./easyrsa gen-dh
openvpn --genkey secret ta.key
cp pki/ca.crt pki/issued/server.crt pki/private/server.key dh.pem ta.key /etc/openvpn/server/
cd ~

PAM_PLUGIN=$(find /usr/lib -type f -name "openvpn-plugin-auth-pam.so" | head -n 1)
cat <<EOF > /etc/openvpn/server/server.conf
port $OVPN_Port
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $Dns_1"
push "dhcp-option DNS $Dns_2"
keepalive 10 120
cipher AES-256-GCM
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE
systemctl enable openvpn-server@server
systemctl restart openvpn-server@server

# === HARDCODED CERTIFICATE ===
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
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem; chown root:root /etc/stunnel/stunnel.pem

cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">GURUZGH | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font><br>
deekay77

# OpenSSH & Dropbear & SSLH & Stunnel
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
sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config; sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config; sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

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
sed -i "s|PORT01|$Dropbear_Port1|g" /etc/default/dropbear; sed -i "s|PORT02|$Dropbear_Port2|g" /etc/default/dropbear
systemctl restart "$DROPBEAR_SERVICE"

cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$Dropbear_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl restart "$SSLH_SERVICE"

StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
MyStunnelD
cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[sslh]
accept = Stunnel_Port
connect = 127.0.0.1:MainPort
MyStunnelC
sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf; sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl restart "$STUNNEL_SERVICE"

# Node.js Socks Proxy
mkdir -p /etc/socksproxy; apt-get install -y nodejs
cat <<EOF > /etc/socksproxy/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { });
const TARGET_HOST = '127.0.0.1'; const TARGET_PORT = $Dropbear_Port1; const LISTEN_PORT = parseInt(process.argv[2]);
const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            clientSocket.write('HTTP/1.1 101 Switching Protocols\r\n\r\n');
            clientSocket.pipe(targetSocket); targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
    });
    clientSocket.on('error', () => {});
};
net.createServer(handleConnection).listen(LISTEN_PORT, '0.0.0.0');
EOF
cat <<'service' > /etc/systemd/system/ws-proxy@.service
[Unit]
Description=Node.js WebSocket Proxy on port %i
[Service]
Type=simple
User=root
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js %i
Restart=always
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
service
systemctl daemon-reload
for port in "${WsPorts[@]}"; do systemctl enable --now ws-proxy@$port; done

# === XRAY CORE (Added Shadowsocks Port 8388) ===
echo "Installing Xray Core..."
wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -q /tmp/xray.zip -d /tmp/xray/; mv /tmp/xray/xray /usr/local/bin/xray; chmod +x /usr/local/bin/xray; rm -rf /tmp/xray*
touch /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt /etc/xray/shadowsocks.txt

cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [], "decryption": "none",
        "fallbacks": [ { "path": "/vmess", "dest": 10001 }, { "path": "/trojan", "dest": 10002 }, { "path": "/vless", "dest": 10003 }, { "dest": 666 } ]
      },
      "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "alpn": ["http/1.1"], "certificates": [ { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" } ] } }
    },
    { "listen": "127.0.0.1", "port": 10001, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "listen": "127.0.0.1", "port": 10002, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    {
      "port": "80,8080,8880",
      "protocol": "vless",
      "settings": { "clients": [], "decryption": "none", "fallbacks": [ { "path": "/vless", "dest": 10003 }, { "path": "/vmess", "dest": 10004 }, { "dest": 666 } ] },
      "streamSettings": { "network": "tcp" }
    },
    { "listen": "127.0.0.1", "port": 10003, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "listen": "127.0.0.1", "port": 10004, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "port": 8388, "protocol": "shadowsocks", "settings": { "clients": [], "network": "tcp,udp" } }
  ],
  "outbounds": [ { "protocol": "freedom" }, { "protocol": "blackhole", "tag": "blocked" } ]
}
EOF
mkdir -p /var/log/xray
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
[Service]
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable --now xray

# Nginx & Squid
mkdir -p /home/vps/public_html
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { include /etc/nginx/mime.types; default_type application/octet-stream; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } location /client.ovpn { default_type application/x-openvpn-profile; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl ports_ port 14 22 53 21 8081 25 8000 3128 443 80 8080 8880 2082 2086 1194 8388
http_port Squid_Port1
http_port Squid_Port2
http_access allow server
http_access allow all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

# Aggressive Sysctl
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
fs.file-max = 1048576
net.core.somaxconn = 65535
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
SYSCTL
sysctl --system >/dev/null 2>&1 || true

# SlowDNS
mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server
iptables -I INPUT -p udp --dport 53 -j ACCEPT
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :53 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:80
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl enable --now server-sldns

# === HYSTERIA v1 & v2 (Sing-box) ===
warp-cli --accept-tos registration new >/dev/null 2>&1 || true
warp-cli --accept-tos mode proxy >/dev/null 2>&1 || true
warp-cli --accept-tos connect >/dev/null 2>&1 || true
bash <(curl -fsSL https://sing-box.app/deb-install.sh) >/dev/null 2>&1
mkdir -p /etc/hysteria
cat << EOF > /etc/hysteria/config.json
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria", "tag": "hy1-inbound", "listen": "::", "listen_port": ${UDP_PORT##*:},
      "up_mbps": 100, "down_mbps": 100, "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/xray/xray.crt", "key_path": "/etc/xray/xray.key" }
    },
    {
      "type": "hysteria2", "tag": "hy2-inbound", "listen": "::", "listen_port": ${UDP_PORT2##*:},
      "up_mbps": 100, "down_mbps": 100, "obfs": {"type": "salamander", "password": "$OBFS"},
      "users": [ { "password": "$PASSWORD" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/xray/xray.crt", "key_path": "/etc/xray/xray.key" }
    }
  ],
  "outbounds": [ { "type": "socks", "tag": "warp-proxy", "server": "127.0.0.1", "server_port": 40000 }, { "type": "direct", "tag": "direct" } ],
  "route": { "rules": [ { "inbound": ["hy1-inbound", "hy2-inbound"], "domain_suffix": [ "doubleclick.net", "admob.com", "googlevideo.com", "youtube.com" ], "outbound": "warp-proxy" }, { "inbound": ["hy1-inbound", "hy2-inbound"], "outbound": "direct" } ] }
}
EOF
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/hysteria/users.txt
cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Sing-Box Hysteria Dual Core
[Service]
ExecStart=/usr/bin/sing-box run -c /etc/hysteria/config.json
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
iptables -I INPUT -p udp --dport ${UDP_PORT##*:} -j ACCEPT
iptables -I INPUT -p udp --dport ${UDP_PORT2##*:} -j ACCEPT
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 20000:40000 -j DNAT --to-destination ${UDP_PORT}
iptables -t nat -A PREROUTING -i $IFACE -p udp --dport 50000:60000 -j DNAT --to-destination ${UDP_PORT2}
systemctl daemon-reload; systemctl enable --now hysteria-server

# MENU CREATION
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'
DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s ipv4.icanhazip.com)

# Functions
server_ip() { curl -4 -s ipv4.icanhazip.com || hostname -I | awk '{print $1}'; }
pause_return() { echo; read -rp "Press ENTER to return... " _; }

add_hysteria() {
    clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                 ${BOLD}CREATE HYSTERIA (V1 & V2) USER${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Enter Password: " new_pass
    if grep -qw "^$new_pass" "/etc/hysteria/users.txt" 2>/dev/null; then echo -e "\n${RED}User exists!${NC}"; pause_return; return; fi
    read -rp " Validity (Days): " days
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}] | .inbounds[1].users += [{\"password\": \"$new_pass\"}]" /etc/hysteria/config.json > /tmp/h.json && mv /tmp/h.json /etc/hysteria/config.json
    echo "$new_pass $exp_date" >> /etc/hysteria/users.txt; systemctl restart hysteria-server
    
    echo -e "\n${GREEN}✔ User created for both Hysteria V1 & V2!${NC}"
    echo -e " ${BOLD}Domain:${NC}      ${YELLOW}${DOMAIN}${NC}"
    echo -e " ${BOLD}V1 Ports:${NC}    ${YELLOW}20000-40000 (-> 36712)${NC}"
    echo -e " ${BOLD}V2 Ports:${NC}    ${YELLOW}50000-60000 (-> 36713)${NC}"
    echo -e " ${BOLD}Password:${NC}    ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs (V1/V2):${NC} ${YELLOW}GuruzScript / salamander:GuruzScript${NC}"
    echo -e " ${BOLD}Expiry:${NC}      ${YELLOW}${exp_date}${NC}"
    pause_return
}

add_xray() {
  clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}CREATE XRAY ACCOUNT${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e " [1] VLESS (TLS & NTLS)\n [2] VMESS (TLS & NTLS)\n [3] TROJAN (TLS)\n [4] SHADOWSOCKS (AEAD)\n [5] ALL-IN-ONE"
  read -rp " Select: " prot; read -rp " Username: " user
  if grep -qw "^$user" /etc/xray/*.txt 2>/dev/null; then echo -e "${RED}Exists!${NC}"; pause_return; return; fi
  read -rp " Validity (Days): " masa; exp=$(date -d "+${masa} days" +"%Y-%m-%d")
  uuid=$(cat /proc/sys/kernel/random/uuid); pass="Guruz${uuid:0:6}"; CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')

  if [ "$prot" == "4" ] || [ "$prot" == "5" ]; then
    ss_pass=$(cat /proc/sys/kernel/random/uuid | sed 's/-//g' | head -c 16)
    jq ".inbounds[6].settings.clients += [{\"password\": \"$ss_pass\", \"method\": \"chacha20-ietf-poly1305\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $ss_pass $exp" >> /etc/xray/shadowsocks.txt
  fi

  if [ "$prot" == "1" ] || [ "$prot" == "5" ]; then
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[3].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[4].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vless.txt
  fi

  if [ "$prot" == "2" ] || [ "$prot" == "5" ]; then
    jq ".inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}] | .inbounds[5].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
  fi

  if [ "$prot" == "3" ] || [ "$prot" == "5" ]; then
    jq ".inbounds[2].settings.clients += [{\"password\": \"$pass\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $pass $exp" >> /etc/xray/trojan.txt
  fi
  systemctl restart xray
  
  clear; echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}ACCOUNT CREATED${NC}\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "User: $user | Exp: $exp | Domain: $DOMAIN\n"
  [ "$prot" == "1" ] || [ "$prot" == "5" ] && echo -e "${YELLOW}VLESS TLS:${NC} vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&path=%2Fvless\n${YELLOW}VLESS NTLS/DNS:${NC} vless://${uuid}@${DOMAIN}:80?type=ws&security=none&path=%2Fvless\n"
  [ "$prot" == "2" ] || [ "$prot" == "5" ] && echo -e "${YELLOW}VMESS TLS/NTLS:${NC} (Generated internally via ID: ${uuid})\n"
  [ "$prot" == "3" ] || [ "$prot" == "5" ] && echo -e "${YELLOW}TROJAN TLS:${NC} trojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan\n"
  [ "$prot" == "4" ] || [ "$prot" == "5" ] && echo -e "${YELLOW}SHADOWSOCKS:${NC} ss://$(echo -n "chacha20-ietf-poly1305:${ss_pass}" | base64 -w 0)@${DOMAIN}:8388#${user}\n"
  echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-Not Set}${NC}\n  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59\n"
  pause_return
}

generate_ovpn() {
  cat <<EOF > /home/vps/public_html/client.ovpn
client
dev tun
proto tcp
remote $(server_ip) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
auth-user-pass
cipher AES-256-GCM
auth SHA256
key-direction 1
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<tls-auth>
$(cat /etc/openvpn/server/ta.key)
</tls-auth>
EOF
  echo -e "\n${GREEN}✔ OVPN File Generated!${NC}"
  echo -e "${YELLOW}Download link:${NC} http://$(server_ip):85/client.ovpn"
  echo -e "Note: Users authenticate with their SSH Username & Password."
  pause_return
}

create_user() {
  clear; read -rp "  Username: " user; read -rp "  Password: " pass; read -rp "  Days: " days
  useradd -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" && echo "$user:$pass" | chpasswd
  CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')
  clear; echo -e "${GREEN}✔ SSH & OPENVPN ACCOUNT CREATED${NC}\n  User: $user | Pass: $pass | Exp: $(date -d "+$days days" +%Y-%m-%d)\n  SlowDNS NS: ${CURRENT_NS}\n  Pub Key: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  pause_return
}

draw_header() {
  local os="${ID^^} ${VERSION_ID}"; local ip=$(server_ip); local time=$(date '+%H:%M'); local ram=$(free | awk '/Mem:/ {printf "%.1f%%", ($3/$2)*100}')
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-25s${NC} ${WHITE}%-5s${NC} ${YELLOW}%s${NC}\n" "IP:" "$ip" "Time:" "$time"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-25s${NC} ${WHITE}%-5s${NC} ${YELLOW}%s${NC}\n" "OS:" "$os" "RAM:" "$ram"
  echo -e "${CYAN}------------------------ ${BOLD}SERVICES${NC} ${CYAN}------------------------${NC}"
  echo -e "  ${WHITE}SSH/Dropbear:${NC} ${GREEN}22, 299, 790, 550${NC}   ${WHITE}OpenVPN:${NC} ${GREEN}1194${NC}"
  echo -e "  ${WHITE}Xray TLS/NTLS:${NC} ${GREEN}443, 80${NC}          ${WHITE}Shadowsocks:${NC} ${GREEN}8388${NC}"
  echo -e "  ${WHITE}Hysteria V1:${NC} ${GREEN}20000-40000${NC}        ${WHITE}Hysteria V2:${NC} ${GREEN}50000-60000${NC}"
  echo -e "  ${WHITE}SlowDNS:${NC} ${GREEN}53 (Multiplexed)${NC}       ${WHITE}BadVPN:${NC} ${GREEN}7300${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] SSH & OpenVPN Users\n  [${YELLOW}02${NC}] Generate .ovpn Client File\n  [${YELLOW}03${NC}] Xray & SS Users\n  [${YELLOW}04${NC}] Hysteria V1 & V2 Users\n  [${YELLOW}05${NC}] System Utilities (BBR/Netflix)\n  [${RED}00${NC}] Exit\n"
  read -rp "  ► Option: " opt
  case "$opt" in
    1|01) create_user ;;
    2|02) generate_ovpn ;;
    3|03) add_xray ;;
    4|04) add_hysteria ;;
    5|05) bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -M 0 | sed -E -e 's/解锁/Unlocked/g' -e 's/未解锁/Blocked/g' -e 's/失败/Failed/g'; pause_return ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu

# Finishing
chown -R www-data:www-data /home/vps/public_html
clear
figlet GuruzGH Script | lolcat
echo "Installation Complete! Rebooting in 5s..."
sleep 5
reboot
