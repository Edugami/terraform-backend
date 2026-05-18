#!/bin/bash
set -euo pipefail

# Install WireGuard
dnf install -y wireguard-tools

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Get server private key from SSM
SERVER_PRIVATE_KEY=$(aws ssm get-parameter \
  --name "${ssm_path}" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region "${region}")

mkdir -p /etc/wireguard

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${server_vpn_ip}/24
PrivateKey = __SERVER_PRIVATE_KEY__
ListenPort = 51820
PostUp = iptables -I FORWARD -i ens5 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
PostDown = iptables -D FORWARD -i ens5 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens5 -j MASQUERADE
%{ for name, peer in peers ~}

[Peer]
# ${name}
PublicKey = ${peer.public_key}
AllowedIPs = ${peer.vpn_ip}/32
%{ endfor ~}
EOF

# Replace placeholder with actual key (avoids heredoc escaping issues)
sed -i "s|__SERVER_PRIVATE_KEY__|$$SERVER_PRIVATE_KEY|g" /etc/wireguard/wg0.conf

chmod 600 /etc/wireguard/wg0.conf

# Enable and start WireGuard
systemctl enable --now wg-quick@wg0
