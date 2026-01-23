# ============================================================================
# Shared Infrastructure Outputs
# ============================================================================
# These outputs are used by environment-specific configurations (dev/prod)
# ============================================================================

# ============================================================================
# Network
# ============================================================================

output "vpc_id" {
  description = "ID of the shared VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value       = module.network.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value       = module.network.private_db_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = module.network.nat_gateway_public_ip
}

# ============================================================================
# Security Groups
# ============================================================================

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = module.security.alb_sg_id
}

output "app_dev_sg_id" {
  description = "ID of the DEV application security group"
  value       = module.security.app_dev_sg_id
}

output "app_prod_sg_id" {
  description = "ID of the PROD application security group"
  value       = module.security.app_prod_sg_id
}

output "db_dev_sg_id" {
  description = "ID of the DEV database security group"
  value       = module.security.db_dev_sg_id
}

output "db_prod_sg_id" {
  description = "ID of the PROD database security group"
  value       = module.security.db_prod_sg_id
}

# ============================================================================
# ECS Cluster
# ============================================================================

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.cluster_arn
}

# ============================================================================
# ECR
# ============================================================================

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# ============================================================================
# ACM Certificate
# ============================================================================

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.acm.certificate_arn
}

output "certificate_status" {
  description = "Status of the ACM certificate"
  value       = module.acm.certificate_status
}

output "dns_validation_records" {
  description = "DNS records to create manually for certificate validation"
  value       = module.acm.dns_validation_records
}

# ============================================================================
# ALB
# ============================================================================

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = module.alb.alb_arn
}

output "dev_target_group_arn" {
  description = "ARN of the DEV target group"
  value       = module.alb.dev_target_group_arn
}

output "prod_target_group_arn" {
  description = "ARN of the PROD target group"
  value       = module.alb.prod_target_group_arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = module.alb.https_listener_arn
}

# ============================================================================
# GitHub Actions OIDC
# ============================================================================

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = module.github_oidc.role_arn
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

# ============================================================================
# Monitoring
# ============================================================================

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = module.monitoring.sns_topic_arn
}

# ============================================================================
# WAF
# ============================================================================

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}

output "waf_admin_ip_set_arn" {
  description = "ARN of the WAF IP set for admin tools allowlist"
  value       = var.enable_waf ? module.waf[0].ip_set_arn : null
}
