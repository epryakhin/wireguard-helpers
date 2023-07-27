#!/bin/bash

set -e

# Require root to change wg-related settings
if ! [ "$(id -u)" = "0" ]; then
    echo "Error: sudo is required to configure WireGuard clients"
    exit 1
fi

# Help and basic error checking
if [ $# -ne 4 ] || [ $# -gt 1 -a "$1" == "--help" ]; then
	echo "Usage:"
	echo "$(basename "$0") <iface[wg0]> <user> <device> <client_number>"
	exit 1
fi

# Params
iface="$1"
user="$2"
device="$3"
client_number="$4"

iface_conf="/etc/wireguard/${iface}.conf"
script_conf="/etc/wireguard/${iface}/${iface}.client"

. "${script_conf}"

# Pull server pubkey from file
server_pub=$(< "$server_key_pub")

# Generate and store keypair
priv=$(wg genkey)
pub=$(echo "$priv" | wg pubkey)

# Create IPv4/6 addresses based on client ID
client_ipv4="${ipv4_prefix}${client_number}/$ipv4_mask"

# Can't add duplicate IPs
if grep -q "$client_ipv4" "$iface_conf"; then
	echo "Error: This client number has already been used in the config file"
	exit 1
fi

# Add peer to config file (blank line is on purpose)
cat >> $iface_conf <<-EOM

[Peer]
# $user.$device
PublicKey = $pub
AllowedIPs = $client_ipv4
EOM

# Make client config
client_config=$(cat <<-EOM
[Interface]
PrivateKey = $priv
Address = $client_ipv4
DNS = $dns_servers

[Peer]
PublicKey = $server_pub
AllowedIPs = $allowed_ips
Endpoint = $server_domain:$server_port
PersistentKeepalive = 25
EOM
)

# Output client configuration
echo "########## START CONFIG ##########"
echo "$client_config"
echo "########### END CONFIG ###########"
if command -v qrencode > /dev/null; then
	echo "$client_config" | qrencode -t ansiutf8
else
	echo "Install 'qrencode' to also generate a QR code of the above config"
fi

# Restart service
echo ""
read -p "Restart 'wg-quick@$iface' ? [y]: " confirm
if [ $confirm == "y" ]; then
	systemctl restart "wg-quick@$iface"
else
	echo "WARNING: 'wg-quick@$iface' will need to be restarted before the new client can connect"
fi
