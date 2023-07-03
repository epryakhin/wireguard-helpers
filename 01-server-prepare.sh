#!/bin/bash

# Require root to change wg-related settings
if ! [ "$(id -u)" = "0" ]; then
    echo "ERROR: sudo is required to configure WireGuard clients"
    exit 1
fi

# update server first
apt update && apt upgrade

# --- create new user ---
# read user name and password from user input
echo -n "Enter user name: "
read $user
adduser "$user"
# read user from variable
usermod -aG sudo "$user"

# --- configure SSH ---
# generate random port number
port=$(( $RANDOM + 10000 ))
echo "Generated random SSH port number: $port"
# set sshd port
sed "s/#Port 22/Port $port/" /etc/ssh/sshd_config
# allow only public key auth, no root login
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# copy public key
mkdir "/home/$user/.ssh/"
cp key "/home/$user/.ssh/authorized_keys"
chown -R "$user":"$user" "/home/$user/.ssh"
# restart sshd.service
read -p "SSH service will be restarted on port [$port] with no password login and no root login. Are use sure? [Yy]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
 systemctl reload sshd.service
fi

# configure ufw
# set defaults
ufw default deny incoming
ufw default allow outgoing
# allow new ssh port
ufw allow "$port"
# print rules
ufw show added
# enable
ufw enable

# enable ipv4/ipv6 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.default.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1
