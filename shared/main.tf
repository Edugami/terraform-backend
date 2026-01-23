# ============================================================================
# Shared Infrastructure
# ============================================================================
# VPC, Security Groups, ALB, ECS Cluster, ECR, ACM Certificate
# Shared between DEV and PROD environments
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}

# ============================================================================
# Network Module (Shared VPC with single NAT Gateway)
# ============================================================================

module "network" {
  source = "../modules/network"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# ============================================================================
# Security Groups Module (Environment-isolated)
# ============================================================================

module "security" {
  source = "../modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
}

# ============================================================================
# ECR Repository
# ============================================================================

module "ecr" {
  source = "../modules/ecr"

  project_name = var.project_name
}

# ============================================================================
# ECS Cluster (Shared)
# ============================================================================

module "ecs_cluster" {
  source = "../modules/ecs-cluster"

  project_name              = var.project_name
  enable_container_insights = var.enable_container_insights
}

# ============================================================================
# ACM Certificate (Manual DNS Validation)
# ============================================================================

module "acm" {
  source = "../modules/acm"

  project_name = var.project_name
  domain_name  = var.domain_name
}

# ============================================================================
# Shared ALB with Host-Based Routing
# ============================================================================

module "alb" {
  source = "../modules/alb"

  project_name               = var.project_name
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  alb_security_group_id      = module.security.alb_sg_id
  certificate_arn            = module.acm.certificate_arn
  enable_deletion_protection = var.enable_alb_deletion_protection
  dev_host_headers           = var.dev_host_headers
  prod_host_headers          = var.prod_host_headers
}

# ============================================================================
# GitHub Actions OIDC (CI/CD)
# ============================================================================

module "github_oidc" {
  source = "../modules/github-oidc"

  project_name       = var.project_name
  github_org         = var.github_org
  github_repo        = var.github_repo
  ecr_repository_arn = module.ecr.repository_arn
  ecs_cluster_arn    = module.ecs_cluster.cluster_arn
}

# ============================================================================
# Monitoring (SNS + AWS Chatbot for Slack)
# ============================================================================

module "monitoring" {
  source = "../modules/monitoring"

  project_name = var.project_name
  alert_emails = var.alert_emails

  # Slack integration (optional)
  enable_slack_notifications = var.enable_slack_notifications
  slack_workspace_id         = var.slack_workspace_id
  slack_channel_id           = var.slack_channel_id
}

# ============================================================================
# WAF (Web Application Firewall) - Protects Admin Tools
# ============================================================================
# Restricts access to pgAdmin and Redis Commander to allowed IP addresses
# Also includes AWS Managed Rules for common attack protection
# ============================================================================

module "waf" {
  count  = var.enable_waf ? 1 : 0
  source = "../modules/waf"

  project_name = var.project_name
  alb_arn      = module.alb.alb_arn

  # IP allowlist for admin tools (pgadmin-*.edugami.pro, redis-*.edugami.pro)
  admin_allowed_cidrs = var.admin_allowed_cidrs

  # AWS Managed Rules (recommended)
  enable_aws_managed_rules = var.enable_aws_managed_rules

  # Rate limiting
  rate_limit = var.waf_rate_limit

  # Logging
  enable_waf_logging = var.enable_waf_logging
}
