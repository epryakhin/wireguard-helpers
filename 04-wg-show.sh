#!/bin/bash

# Require root to see wg-related settings
if ! [ "$(id -u)" = "0" ]; then
    echo "ERROR: sudo is required to configure WireGuard clients"
    exit 1
fi

# Help and basic error checking
if [ $# -ge 1 -a "$1" == "--help" ]; then
        echo "Usage:"
        echo "$(basename "$0") <iface:[wg0]>"
        exit 1
fi

iface="${1:-wg0}"
conf_file="/etc/wireguard/$iface.conf"

if [ ! -f $conf_file ]; then
 echo "Interface $iface not configured"
 exit 1
fi

conf=$(< $conf_file)

wg show "$iface" | while read -r line
do
 res=$(echo "$line" | grep peer)
 if [ -z "$res" ]; then
  echo $line
 else
  key=$(echo $line | sed 's/\(peer: \)\(.*\)/\2/')
  name=$(echo "$conf" | grep -B1 "$key" | grep -v "$key" | sed 's/\# //')
  echo "peer: ${key} | $name"
 fi
done
