#!/bin/bash

set -e

# Require root to change wg-related settings
if ! [ "$(id -u)" = "0" ]; then
    echo "ERROR: sudo is required to configure WireGuard clients"
    exit 1
fi

read -p "Enter interface name [wg0]: " iface
iface=${iface:-wg0}

# ! check interface already exists

wg_path=/etc/wireguard
iface_path="$wg_path/$iface"

### Generate server keypair
mkdir -p "$iface_path"
key_path="$iface_path/$iface.key"
key_path_pub="$key_path.pub"
touch "$key_path"
chmod 600 "$key_path"
wg genkey | tee "$key_path" | wg pubkey > "$key_path_pub"

priv_key=`cat "$key_path"`

# read wg server configiration
read -p "Enter ipv4 prefix [172.16.0.]: " ipv4_prefix
ipv4_prefix=${ipv4_prefix:-172.16.0.}
read -p "Enter wg port [51820]: " port
port=${port:-51820}

# generate iface cfg
conf="$iface_path/$iface.conf"
# ! get default ip route interface
cat >> $conf <<-EOM
[Interface]
 PrivateKey = "$priv"
 Address = "$ipv4_prefix"
 ListenPort = "$port"
 SaveConfig = false
 PostUp = ufw route allow in on "$iface" out on ens3
 PostUp = ufw route allow in on ens3 out on "$iface"
 PostUp = iptables -t nat -I POSTROUTING -o ens3 -j MASQUERADE
 PostUp = ip6tables -t nat -I POSTROUTING -o ens3 -j MASQUERADE
 PreDown = ufw route delete allow in on "$iface" out on ens3
 PreDown = ufw route delete allow in on ens3 out on "$iface"
 PreDown = iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE
 PreDown = ip6tables -t nat -D POSTROUTING -o ens3 -j MASQUERADE
EOM

# ! set up iface conf file for client-make.sh script

# ! allow wg port on ufw

# ! make systemd service, print its name, then start
