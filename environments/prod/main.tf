# ============================================================================
# PROD Environment Configuration
# ============================================================================
# Robust instances for production reliability
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ============================================================================
# Reference Shared Infrastructure State
# ============================================================================

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "edugami-terraform-state"
    key    = "shared/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# PROD App Cluster
# ============================================================================

module "app_cluster" {
  source = "../../modules/app-cluster"

  project_name = var.project_name
  environment  = var.environment

  # Network (from shared state)
  vpc_id                 = data.terraform_remote_state.shared.outputs.vpc_id
  private_app_subnet_ids = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
  private_db_subnet_ids  = data.terraform_remote_state.shared.outputs.private_db_subnet_ids
  app_security_group_id  = data.terraform_remote_state.shared.outputs.app_prod_sg_id
  db_security_group_id   = data.terraform_remote_state.shared.outputs.db_prod_sg_id

  # ECS (from shared state)
  ecs_cluster_id     = data.terraform_remote_state.shared.outputs.ecs_cluster_id
  ecs_cluster_name   = data.terraform_remote_state.shared.outputs.ecs_cluster_name
  target_group_arn   = data.terraform_remote_state.shared.outputs.prod_target_group_arn
  ecr_repository_url = data.terraform_remote_state.shared.outputs.ecr_repository_url
  image_tag          = var.image_tag

  # Web Service (On-Demand)
  web_cpu           = var.web_cpu
  web_memory        = var.web_memory
  web_desired_count = var.web_desired_count
  web_min_count     = var.web_min_count
  web_max_count     = var.web_max_count

  # Worker Service (Spot)
  worker_cpu           = var.worker_cpu
  worker_memory        = var.worker_memory
  worker_desired_count = var.worker_desired_count
  worker_min_count     = var.worker_min_count
  worker_max_count     = var.worker_max_count
  sidekiq_concurrency  = var.sidekiq_concurrency
  sidekiq_timeout      = var.sidekiq_timeout

  # RDS
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_multi_az          = var.db_multi_az

  # Redis
  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes

  # Rails (secrets are now in SSM Parameter Store)
  rails_env         = var.rails_env
  rails_max_threads = var.rails_max_threads

  # Auto-scaling
  cpu_target_value    = var.cpu_target_value
  memory_target_value = var.memory_target_value

  # Additional environment variables (optional)
  additional_env_vars = var.additional_env_vars

  # Admin Tools (pgAdmin, Redis Commander)
  enable_admin_tools       = var.enable_admin_tools
  https_listener_arn       = data.terraform_remote_state.shared.outputs.https_listener_arn
  pgadmin_email            = var.pgadmin_email
  pgadmin_password         = var.pgadmin_password
  redis_commander_user     = var.redis_commander_user
  redis_commander_password = var.redis_commander_password

  # Monitoring / Alerting
  alarm_sns_topic_arn = data.terraform_remote_state.shared.outputs.alarm_sns_topic_arn
}
