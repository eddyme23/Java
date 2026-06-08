#!/bin/bash

# --- Color Formatting & Utilities ---
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}

# --- Dependency Checker ---
echo "Checking dependencies..."
sudo apt-get update -y > /dev/null 2>&1
for pkg in qrencode jq net-tools openssl wget curl nano iptables-persistent; do
    if ! command -v $pkg &> /dev/null; then
        yellow "$pkg is not installed. Installing..."
        sudo apt-get install $pkg -y > /dev/null 2>&1
    fi
done
green "Dependencies are installed."

# --- 1. Install / Update Hysteria V2 ---
run_hysteria_v2_setup() {
    clear
    echo "Running Hysteria v2 Setup (Guruz Edition: Port-Hopping + Obfuscation)..."
    sleep 1

    if [ "$EUID" -eq 0 ]; then
        user_directory="/root/hy2"
    else
        user_directory="/home/$USER/hy2"
    fi

    if [ -d "$user_directory" ]; then
        clear
        echo "--------------------------------------------------------------------------------"
        echo -e "\e[1;33mHysteria directory already exists. Checking for latest version..\e[0m"
        echo "--------------------------------------------------------------------------------"
        sleep 2

        if [ -f "$user_directory/config.json" ]; then
            password=$(jq -r '.auth.password' <<< "$(< "$user_directory/config.json")")
        else
            echo "Error: config.json file not found in Hysteria directory."
            return
        fi
    else
        # Matching your xfc.sh exact parameters
        base_port="36712"
        range_start="20000"
        range_end="50000"
        
        readp "Enter the Connection/Obfuscation password: " password

        mkdir -p "$user_directory"
        cd "$user_directory"

        # Crash-Proof JSON config (listening on base port 36712 with Salamander enabled)
        cat << EOF > "$user_directory/config.json"
{
  "listen": ":$base_port",
  "obfs": {
    "type": "salamander",
    "salamander": {
      "password": "$password"
    }
  },
  "tls": {
    "cert": "$user_directory/ca.crt",
    "key": "$user_directory/ca.key"
  },
  "auth": {
    "type": "password",
    "password": "$password"
  },
  "bandwidth": {
    "up": "1 gbps",
    "down": "1 gbps"
  },
  "ignoreClientBandwidth": false,
  "disableUDP": false,
  "udpIdleTimeout": "60s"
}
EOF

        # Apply IPTables routing for Port Hopping (20000-50000 -> 36712)
        echo "Applying iptables rules for UDP port hopping ($range_start-$range_end)..."
        iptables -t nat -C PREROUTING -p udp --dport $range_start:$range_end -j DNAT --to-destination :$base_port 2>/dev/null || iptables -t nat -A PREROUTING -p udp --dport $range_start:$range_end -j DNAT --to-destination :$base_port
        ip6tables -t nat -C PREROUTING -p udp --dport $range_start:$range_end -j DNAT --to-destination :$base_port 2>/dev/null || ip6tables -t nat -A PREROUTING -p udp --dport $range_start:$range_end -j DNAT --to-destination :$base_port
        
        # Save firewall rules
        netfilter-persistent save >/dev/null 2>&1 || true
    fi

    latest_version=$(curl -s https://api.github.com/repos/apernet/hysteria/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    echo -e "\e[1;33m---> Installing hysteria ver $latest_version\e[0m"
    echo "--------------------------------------------------------------------------------"
    sleep 2

    rm -f hysteria-linux-amd64

    architecture=$(uname -m)
    if [ "$architecture" = "x86_64" ]; then
        wget -q --show-progress "https://github.com/apernet/hysteria/releases/download/$latest_version/hysteria-linux-amd64"
    else
        wget -q --show-progress "https://github.com/apernet/hysteria/releases/download/$latest_version/hysteria-linux-arm"
        mv hysteria-linux-arm hysteria-linux-amd64
    fi

    chmod 755 hysteria-linux-amd64

    if [ ! -f "$user_directory/ca.key" ] || [ ! -f "$user_directory/ca.crt" ]; then
        openssl ecparam -genkey -name prime256v1 -out "$user_directory/ca.key"
        openssl req -new -x509 -days 36500 -key "$user_directory/ca.key" -out "$user_directory/ca.crt" -subj "/CN=bing.com" 2>/dev/null
    fi

    if [ ! -f "/etc/systemd/system/hy2.service" ]; then
        cat << EOF > /etc/systemd/system/hy2.service
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=$user_directory
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=$user_directory/hysteria-linux-amd64 -c $user_directory/config.json server
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable hy2
    fi

    systemctl restart hy2
    green "Hysteria V2 (Port Hopping + Obfuscation) Installation Complete!"
}

# --- 2. Change Parameters ---
change_hy2_parameters() {
    local user_directory
    if [ "$EUID" -eq 0 ]; then user_directory="/root/hy2"; else user_directory="/home/$USER/hy2"; fi

    if [ -d "$user_directory" ]; then
        echo "Hysteria directory exists. You can change parameters here."
        password=$(jq -r '.auth.password' "$user_directory/config.json")
        readp "Enter a new password [$password]: " new_password
        
        jq ".auth.password = \"${new_password:-$password}\" | .obfs.salamander.password = \"${new_password:-$password}\"" "$user_directory/config.json" > tmp_config.json
        mv tmp_config.json "$user_directory/config.json"
        
        systemctl restart hy2
        green "Parameters updated successfully."
    else
        red "Hysteria directory does not exist. Please install Hysteria first."
    fi
}

# --- 3. Show Configs ---
show_hy2_configs() {
    local user_directory
    if [ "$EUID" -eq 0 ]; then user_directory="/root/hy2"; else user_directory="/home/$USER/hy2"; fi

    if [ -d "$user_directory" ]; then
        password=$(jq -r '.auth.password' "$user_directory/config.json")
        base_port=$(jq -r '.listen' "$user_directory/config.json" | cut -c 2-)
        
        systemctl stop wg-quick@wgcf 2>/dev/null || true
        export IPV4=$(curl -s --max-time 3 https://v4.ident.me || curl -s --max-time 3 https://api.ipify.org)
        systemctl restart wg-quick@wgcf 2>/dev/null || true

        # Formatted cleanly with Obfuscation and Port Hopping for Android App parsing
        IPV4_URL="hysteria2://$password@$IPV4:$base_port/?mport=20000-50000&obfs=salamander&obfs-password=$password&insecure=1&sni=bing.com#GuruzVPN-Hy2"

        clear
        echo "----------------config info-----------------"
        echo -e "\e[1;33mPassword: $password\e[0m"
        echo "--------------------------------------------"
        echo
        echo "----------------IP and Port-----------------"
        echo -e "\e[1;33mBase Port:   $base_port\e[0m"
        echo -e "\e[1;33mPort Range:  20000-50000\e[0m"
        echo -e "\e[1;33mIPv4:        $IPV4\e[0m"
        echo -e "\e[1;33mObfuscation: Salamander Enabled\e[0m"
        echo "--------------------------------------------"
        echo
        echo "----------------Android / v2rayNG URL-----------------"
        echo -e "\e[1;33m$IPV4_URL\e[0m"
        echo "--------------------------------------------"
        echo "Scanning QR Code below:"
        qrencode -t ANSIUTF8 "$IPV4_URL"
        echo "--------------------------------------------"
    else
        red "Hysteria directory does not exist. Please install Hysteria first."
    fi

    read -p "Press Enter to continue..."
}

# --- 4. Delete Hysteria ---
delete_hysteria_v2() {
    clear
    echo "Deleting Hysteria v2 Proxy & Firewall rules..."
    sleep 2
    
    # Remove NAT routing rules
    iptables -t nat -D PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || true
    ip6tables -t nat -D PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || true
    netfilter-persistent save >/dev/null 2>&1 || true

    rm -rf /root/hy2 /home/*/hy2 2>/dev/null
    systemctl stop hy2 2>/dev/null
    systemctl disable hy2 2>/dev/null
    rm -f /etc/systemd/system/hy2.service
    systemctl daemon-reload
    
    red "Hysteria V2 has been completely removed."
    read -p "Press Enter to continue..."
}

# --- Main Menu Loop ---
while true; do
    clear
    echo "**********************************************"
    yellow " Guruz Hysteria V2 Menu (Hopping + Salamander)"
    echo "**********************************************"
    green "1. Install/Update"
    echo
    green "2. Change Parameters"
    echo
    green "3. Show Configs & URI Link"
    echo
    green "4. Delete"
    echo
    red "0. Exit"
    echo "**********************************************"
    
    readp "Enter your choice: " hysteria_v2_choice

    case "$hysteria_v2_choice" in
        1)
            run_hysteria_v2_setup
            show_hy2_configs
            ;;
        2)
            change_hy2_parameters
            show_hy2_configs
            ;;
        3)
            show_hy2_configs
            ;;
        4)
            delete_hysteria_v2
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo
            red "Invalid choice. Please select a valid option!"
            sleep 1
            ;;
    esac
done
