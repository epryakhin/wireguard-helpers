#!/bin/bash

set -e

### Require root to change wg-related settings
if ! [ "$(id -u)" = "0" ]; then
    echo "ERROR: sudo is required to configure WireGuard clients"
    exit 1
fi

read -p "Enter interface name [wg0]: " iface
iface=${iface:-wg0}

wg_path="/etc/wireguard"

### Generate server keypair
iface_path="$wg_path/$iface"
if [ -d "$iface_path" ]
then
 echo "Error: interface $iface already configured"
 exit 1
fi
mkdir -p "$iface_path"
key_path="$iface_path/${iface}.key"
key_path_pub="${key_path}.pub"
touch "$key_path"
chmod 600 "$key_path"
wg genkey | tee "$key_path" | wg pubkey > "$key_path_pub"

### read server configiration
read -p "Enter ipv4 prefix [172.16.0.]: " ipv4_prefix
ipv4_prefix=${ipv4_prefix:-172.16.0.}
read -p "Enter wg port [51820]: " port
port=${port:-51820}
ip=`ip -f inet addr show ens3 | awk '/inet / {print $2}' | sed 's/\/32//'`

### generate iface cfg
conf_file="${iface_path}.conf"
iface_default=`ip route show default | awk '/default/ {print $5}'`
cat >> $conf_file <<-EOM
[Interface]
 PrivateKey = `cat $key_path`
 Address = ${ipv4_prefix}1/24
 ListenPort = $port
 SaveConfig = false
 PostUp = ufw route allow in on $iface out on $iface_default
 PostUp = ufw route allow in on $iface_default out on $iface
 PostUp = iptables -t nat -I POSTROUTING -o $iface_default -j MASQUERADE
 PostUp = ip6tables -t nat -I POSTROUTING -o $iface_default -j MASQUERADE
 PreDown = ufw route delete allow in on $iface out on $iface_default
 PreDown = ufw route delete allow in on $iface_default out on $iface
 PreDown = iptables -t nat -D POSTROUTING -o $iface_default -j MASQUERADE
 PreDown = ip6tables -t nat -D POSTROUTING -o $iface_default -j MASQUERADE
EOM

### generate conf for 03-client-make.sh
client_conf_file="$iface_path/${iface}.client"
cat >> $client_conf_file <<-EOM
 server_key_pub="$key_path_pub"
 server_domain="$ip"
 server_port="$port"
 ipv4_prefix="$ipv4_prefix"
 ipv4_mask="32"
 dns_servers="1.1.1.1, 1.0.0.1"
 allowed_ips="1.0.0.0/8, 2.0.0.0/8, 3.0.0.0/8, 4.0.0.0/6, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 1.1.1.1/32, 8.8.8.8/32"
EOM

### allow wg port on fw and start
ufw allow "${port}/udp"
systemctl start "wg-quick@${iface}.service"
