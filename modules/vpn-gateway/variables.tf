variable "name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_id" { type = string }
variable "ssh_public_key" {
  description = "Public SSH key for EC2 key pair"
  type        = string
}
variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed SSH access (port 22)"
  type        = list(string)
  default     = []
}
variable "instance_type" {
  type    = string
  default = "t3.nano"
}
variable "wireguard_vpn_cidr" {
  type    = string
  default = "10.8.0.0/24"
}
variable "wireguard_server_private_key_ssm_path" {
  description = "SSM path for WireGuard server private key"
  type        = string
}
variable "wireguard_peers" {
  description = "Map of peer name to public_key and vpn_ip"
  type = map(object({
    public_key = string
    vpn_ip     = string
  }))
  default = {}
}
variable "security_group_description" {
  description = "Descripcion del Security Group (inmutable en AWS — no cambiar una vez creado)"
  type        = string
  default     = "Managed by Terraform"
}

variable "tags" {
  type    = map(string)
  default = {}
}
