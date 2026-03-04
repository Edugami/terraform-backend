# ============================================================================
# Bastion Host para SSH Tunnel de n8n -> RDS
# ============================================================================
# n8n en Railway se conecta via SSH tunnel a traves de este bastion.
# El bastion vive en subnet publica con Elastic IP fija.
# RDS permanece en subnet privada con publicly_accessible = false.
# ============================================================================

# ----------------------------------------------------------------------------
# Key Pair
# ----------------------------------------------------------------------------

resource "aws_key_pair" "bastion" {
  key_name   = "edugami-bastion-prod"
  public_key = var.bastion_ssh_public_key

  tags = {
    Name        = "edugami-bastion-prod"
    Environment = "prod"
  }
}

# ----------------------------------------------------------------------------
# Security Group del Bastion
# Ingress: SSH solo desde la IP estatica de Railway
# Egress:  PostgreSQL solo hacia el SG del RDS prod
# ----------------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name        = "edugami-bastion-prod-sg"
  description = "Bastion host para SSH tunnel de n8n a RDS prod"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    description = "SSH desde n8n en Railway"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.railway_n8n_ip_cidr]
  }

  egress {
    description = "PostgreSQL hacia RDS prod"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "edugami-bastion-prod-sg"
    Environment = "prod"
  }
}

# ----------------------------------------------------------------------------
# Regla en el SG del RDS: permite trafico desde el bastion
# ----------------------------------------------------------------------------

resource "aws_security_group_rule" "bastion_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = data.terraform_remote_state.shared.outputs.db_prod_sg_id
  description              = "PostgreSQL desde bastion (SSH tunnel n8n)"
}

# ----------------------------------------------------------------------------
# AMI Amazon Linux 2023
# ----------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ----------------------------------------------------------------------------
# EC2 Bastion t3.nano
# ----------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.nano"
  subnet_id                   = data.terraform_remote_state.shared.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name        = "edugami-bastion-prod"
    Environment = "prod"
    Purpose     = "ssh-tunnel-n8n"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ----------------------------------------------------------------------------
# Elastic IP fija para el bastion
# ----------------------------------------------------------------------------

resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = {
    Name        = "edugami-bastion-prod-eip"
    Environment = "prod"
  }
}
