#!/usr/bin/env bash
# =============================================================================
# generate-vpn-keys.sh
# Genera un keypair WireGuard para un peer (miembro del equipo) o para el
# servidor. Requiere: wireguard-tools (mac: brew install wireguard-tools)
# =============================================================================
set -euo pipefail

MODE=${1:-"peer"}
NAME=${2:-""}

if ! command -v wg &> /dev/null; then
  echo "ERROR: wireguard-tools no instalado."
  echo "  Mac:   brew install wireguard-tools"
  echo "  Linux: sudo apt install wireguard-tools  /  sudo dnf install wireguard-tools"
  exit 1
fi

PRIVATE_KEY=$(wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

if [ "$MODE" = "server" ]; then
  echo ""
  echo "=== SERVER KEYPAIR (una sola vez) ==================================="
  echo ""
  echo "1. Guarda la private key en SSM:"
  echo ""
  echo "   aws ssm put-parameter \\"
  echo "     --name '/edugami/prod/vpn/server_private_key' \\"
  echo "     --value '$PRIVATE_KEY' \\"
  echo "     --type SecureString \\"
  echo "     --region us-east-1"
  echo ""
  echo "2. La public key del servidor (necesaria para los configs de clientes):"
  echo "   $PUBLIC_KEY"
  echo ""
  echo "NUNCA compartas la private key. Solo va a SSM."
  echo "====================================================================="
else
  PEER_NAME=${NAME:-"peer"}
  echo ""
  echo "=== KEYPAIR para: $PEER_NAME ========================================="
  echo ""
  echo "1. Agrega esto a environments/prod/terraform.tfvars en vpn_peers:"
  echo ""
  echo "   \"$PEER_NAME\" = {"
  echo "     public_key = \"$PUBLIC_KEY\""
  echo "     vpn_ip     = \"10.8.0.X\"   # reemplaza X con el siguiente numero disponible"
  echo "   }"
  echo ""
  echo "2. Luego corre: terraform apply"
  echo ""
  echo "3. Config del cliente WireGuard (reemplaza los valores en MAYUSCULAS):"
  echo ""
  echo "   [Interface]"
  echo "   Address = 10.8.0.X/24"
  echo "   PrivateKey = $PRIVATE_KEY"
  echo "   DNS = 8.8.8.8"
  echo ""
  echo "   [Peer]"
  echo "   PublicKey = SERVER_PUBLIC_KEY   # pedirle a Carlos"
  echo "   Endpoint = SERVER_EIP:51820     # pedirle a Carlos"
  echo "   AllowedIPs = 10.0.0.0/16       # solo trafico VPC va por VPN (split tunnel)"
  echo "   PersistentKeepalive = 25"
  echo ""
  echo "NUNCA compartas la private key. Queda solo en tu maquina."
  echo "====================================================================="
fi
