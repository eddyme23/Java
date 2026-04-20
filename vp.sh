#!/bin/bash
set -o pipefail

#by GuruzGH
clear

# Initializing Server
export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

# OS Support Check
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

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "This installer supports Ubuntu 20.04/22.04/24.04 and Debian 11/12/13 only."
  exit 1
fi

# Original Variables from tgst.sh
SSH_Port1='22'
SSH_Port2='299'
Dropbear_Port1='790'
Dropbear_Port2='550'
Stunnel_Port='443' 
Squid_Port1='3128'
Squid_Port2='8000'
WsPorts=('80' '8080' '8880' '25' '2082' '2086') 
WsPort='80' 
MainPort='666'

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
Nginx_Port='85' 
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'
MyVPS_Time='Africa/Accra'
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  echo "${IP}"
} 
IPADDR="$(ip_address)"

apt-get update -y
apt-get upgrade -y --with-new-pkgs

# Smart Dependency Filter
PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid dropbear nano sudo wget unzip tar gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  nginx certbot jq figlet git gcc make build-essential nodejs perl expect libdbi-perl 
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then AVAILABLE_PACKAGES+=("$pkg"); fi
done
apt-get install -y "${AVAILABLE_PACKAGES[@]}"

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

# --- DROPBEAR & SSH (Strict tgst.sh Logic) ---
if command -v dropbearkey >/dev/null 2>&1; then
  [ -f /etc/dropbear/dropbear_rsa_host_key ] || dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
  [ -f /etc/dropbear/dropbear_dss_host_key ] || dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
  [ -f /etc/dropbear/dropbear_ecdsa_host_key ] || dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

mkdir -p /etc/dropbear /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh
ssh-keygen -A >/dev/null 2>&1 || true

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

cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port 22
Port 299
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
Subsystem sftp internal-sftp
MySSHConfig
systemctl restart ssh

cat <<'MyDropbear' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=790
DROPBEAR_EXTRA_ARGS="-p 550"
DROPBEAR_BANNER="/etc/zorro-luffy"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear
systemctl restart dropbear

# --- SSLH & STUNNEL (Strict tgst.sh Logic) ---
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:666 --ssh 127.0.0.1:790 --http 127.0.0.1:80 --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl restart sslh

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
accept = 443
connect = 127.0.0.1:666
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
systemctl restart stunnel4

# --- PASSIVE NODE.JS WS PROXY (New Implementation) ---
loc=/etc/socksproxy
mkdir -p $loc
JS_PORTS="[${WsPorts[*]}]"
JS_PORTS="${JS_PORTS// /, }"

cat <<EOF > $loc/proxy.js
const net = require('net');
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = $Dropbear_Port1;
const LISTEN_PORTS = $JS_PORTS;

const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            targetSocket.write(data);
            clientSocket.pipe(targetSocket);
            targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
        clientSocket.on('error', () => targetSocket.destroy());
    });
    clientSocket.on('error', () => {});
};

LISTEN_PORTS.forEach((port) => {
    net.createServer(handleConnection).listen(port, '0.0.0.0');
});
EOF

cat <<'service' > /etc/systemd/system/ws-proxy.service
[Unit]
Description=Passive Node WS Proxy
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js
Restart=on-failure
[Install]
WantedBy=multi-user.target
service
systemctl daemon-reload; systemctl enable ws-proxy; systemctl restart ws-proxy

# --- HYSTERIA UDP (Strict tgst.sh Logic & Hardcoded Certs) ---
wget -N --no-check-certificate -q -O ~/install_server.sh https://raw.githubusercontent.com/RepositoriesDexter/Hysteria/main/install_server.sh; chmod +x ~/install_server.sh; ./install_server.sh --version v1.3.5
mkdir -p /etc/hysteria
cat > /etc/hysteria/config.json <<EOF
{
  "log_level": "fatal",
  "listen": "$UDP_PORT",
  "cert": "/etc/hysteria/hysteria.crt",
  "key": "/etc/hysteria/hysteria.key",
  "up_mbps": 8,
  "down_mbps": 15,
  "disable_udp": false,
  "obfs": "$OBFS",
  "auth": { "mode": "passwords", "config": ["$PASSWORD"] }
}
EOF

cat << EOF > /etc/hysteria/hysteria.crt
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
systemctl enable hysteria-server; systemctl restart hysteria-server

# --- SLOWDNS (Strict tgst.sh Logic) ---
mkdir -p /etc/slowdns
echo "$Serverkey" > /etc/slowdns/server.key
echo "$Serverpub" > /etc/slowdns/server.pub
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/sldns-server
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=SlowDNS
After=network.target
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :5300 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:299
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl stop systemd-resolved; systemctl disable systemd-resolved; systemctl enable server-sldns; systemctl restart server-sldns

# --- BADVPN & FIREWALL (Original Logic) ---
if [ "$(getconf LONG_BIT)" == "64" ]; then
  wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
  wget -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw
cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn
[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn; systemctl restart badvpn

iptables -F
iptables -t nat -F
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp -m multiport --dports 80,8080,8880,25,2082,2086 -j ACCEPT
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -I INPUT -p udp --dport 36712 -j ACCEPT
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
netfilter-persistent save

# --- MODERNIZED MENU & HEALTH CHECKER (From vp.sh) ---
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m'
mem_stats() { free -h | awk '/Mem:/ {print $2 "|" $3}'; }
cpu_percent() { top -bn1 | awk '/Cpu/ {print $2"%"}'; }
while true; do
  clear
  IFS='|' read -r TOTAL USED <<< "$(mem_stats)"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  OS: $(. /etc/os-release; echo "${ID}")   IP: $(curl -s ipv4.icanhazip.com)"
  echo -e "  RAM: $USED / $TOTAL   CPU: $(cpu_percent)"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  [01] Create User  [02] Delete User  [03] Restart Protocols  [04] Exit"
  read -rp "  Option: " opt
  case "$opt" in
    1) read -p "User: " u; read -p "Pass: " p; read -p "Days: " d; useradd -e $(date -d "+$d days" +%Y-%m-%d) -s /bin/false -M $u; echo "$u:$p" | chpasswd; sleep 2;;
    2) read -p "User: " u; userdel -f $u; sleep 2;;
    3) systemctl restart ssh dropbear ws-proxy stunnel4 hysteria-server server-sldns; sleep 2;;
    4) exit 0;;
  esac
done
EOF_MENU
chmod +x /usr/local/bin/menu; cp /usr/local/bin/menu /usr/bin/menu

# Finishing
history -c; sleep 5; reboot
