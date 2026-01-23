# ============================================================================
# App-Cluster Module - Main Configuration
# ============================================================================
# Reusable module for deploying Rails + Sidekiq application environment
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
