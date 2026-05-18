# ============================================================================
# VPN Gateway (WireGuard + SSH Tunnel para n8n)
# ============================================================================
# El mismo EC2 sirve dos propositos:
#   1. SSH tunnel para n8n (Railway) -> RDS  [comportamiento anterior]
#   2. WireGuard VPN para el equipo -> RDS via DBeaver [nuevo]
# ============================================================================

module "vpn_gateway" {
  source = "../../modules/vpn-gateway"

  name        = "edugami-bastion-prod"
  environment = var.environment

  vpc_id           = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_id = data.terraform_remote_state.shared.outputs.public_subnet_ids[0]

  ssh_public_key    = var.bastion_ssh_public_key
  ssh_allowed_cidrs = [var.railway_n8n_ip_cidr]

  wireguard_server_private_key_ssm_path = "/edugami/prod/vpn/server_private_key"
  wireguard_peers                       = var.vpn_peers
}

# ----------------------------------------------------------------------------
# Regla en el SG del RDS: permite trafico desde el VPN gateway
# El trafico VPN de los clientes llega al RDS con la IP del EC2 (NAT)
# ----------------------------------------------------------------------------

resource "aws_security_group_rule" "bastion_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.vpn_gateway.security_group_id
  security_group_id        = data.terraform_remote_state.shared.outputs.db_prod_sg_id
  description              = "PostgreSQL desde VPN gateway (n8n + equipo via WireGuard)"
}

# ----------------------------------------------------------------------------
# moved blocks: evita destroy/recreate del EC2 y EIP existentes
# Sin estos bloques, Terraform destruiria el EC2 actual y Railway se cae
# ----------------------------------------------------------------------------

moved {
  from = aws_instance.bastion
  to   = module.vpn_gateway.aws_instance.this
}

moved {
  from = aws_eip.bastion
  to   = module.vpn_gateway.aws_eip.this
}

moved {
  from = aws_security_group.bastion
  to   = module.vpn_gateway.aws_security_group.this
}

moved {
  from = aws_key_pair.bastion
  to   = module.vpn_gateway.aws_key_pair.this
}
