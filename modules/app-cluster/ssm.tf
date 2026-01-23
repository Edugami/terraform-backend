# ============================================================================
# SSM Parameter Store - Dynamic Configuration
# ============================================================================
# Reads all parameters from /edugami/{env}/config/ automatically
# Works with both String and SecureString types
# No need to declare each variable in Terraform!
# ============================================================================

# ============================================================================
# SHARED Parameters (for all environments)
# Path: /edugami/shared/config/*
# ============================================================================
data "aws_ssm_parameters_by_path" "shared" {
  path            = "/edugami/shared/config"
  recursive       = true
  with_decryption = false  # We only need names, ECS will decrypt via ARN
}

# ============================================================================
# Environment-specific Parameters
# Path: /edugami/{env}/config/*
# ============================================================================
data "aws_ssm_parameters_by_path" "env" {
  path            = "/edugami/${var.environment}/config"
  recursive       = true
  with_decryption = false  # We only need names, ECS will decrypt via ARN
}

# ============================================================================
# Local variables to transform SSM parameters into ECS secrets format
# All parameters go as "secrets" so ECS handles decryption for both
# String and SecureString types
# ============================================================================
locals {
  # Shared parameters -> map keyed by param name (for merge)
  ssm_shared_map = {
    for name in data.aws_ssm_parameters_by_path.shared.names :
    element(split("/", name), length(split("/", name)) - 1) => {
      name      = element(split("/", name), length(split("/", name)) - 1)
      valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${name}"
    }
  }

  # Environment-specific parameters -> map keyed by param name (for merge)
  ssm_env_map = {
    for name in data.aws_ssm_parameters_by_path.env.names :
    element(split("/", name), length(split("/", name)) - 1) => {
      name      = element(split("/", name), length(split("/", name)) - 1)
      valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${name}"
    }
  }

  # Merged map: env overrides shared if same key exists
  ssm_merged_map = merge(local.ssm_shared_map, local.ssm_env_map)

  # Convert merged map back to list for ECS secrets format
  ssm_secrets = values(local.ssm_merged_map)

  # Empty config env since all params go as secrets now
  ssm_config_env = []
}
