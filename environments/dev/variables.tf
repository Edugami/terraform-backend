# ============================================================================
# DEV Environment Variables
# ============================================================================

# ============================================================================
# General
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "edugami"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

# ============================================================================
# Web Service
# ============================================================================

variable "web_cpu" {
  description = "CPU units for web service"
  type        = number
  default     = 512
}

variable "web_memory" {
  description = "Memory for web service (MB)"
  type        = number
  default     = 1024
}

variable "web_desired_count" {
  description = "Desired count for web tasks"
  type        = number
  default     = 1
}

variable "web_min_count" {
  description = "Minimum count for web tasks"
  type        = number
  default     = 1
}

variable "web_max_count" {
  description = "Maximum count for web tasks"
  type        = number
  default     = 2
}

# ============================================================================
# Worker Service
# ============================================================================

variable "worker_cpu" {
  description = "CPU units for worker service"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Memory for worker service (MB)"
  type        = number
  default     = 512
}

variable "worker_desired_count" {
  description = "Desired count for worker tasks"
  type        = number
  default     = 1
}

variable "worker_min_count" {
  description = "Minimum count for worker tasks"
  type        = number
  default     = 1
}

variable "worker_max_count" {
  description = "Maximum count for worker tasks"
  type        = number
  default     = 2
}

variable "sidekiq_concurrency" {
  description = "Sidekiq concurrency (-c flag)"
  type        = number
  default     = 3
}

variable "sidekiq_timeout" {
  description = "Sidekiq timeout (-t flag)"
  type        = number
  default     = 300
}

# ============================================================================
# RDS
# ============================================================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage (GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "edugami_platform"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "edugami_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password. Only needed for initial RDS creation. If not set, a secure random password is generated."
  type        = string
  sensitive   = true
  default     = null
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# ============================================================================
# Redis
# ============================================================================

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

# ============================================================================
# Rails
# Note: Secrets (RAILS_MASTER_KEY, DEVISE_JWT_SECRET_KEY) are now in SSM Parameter Store
# ============================================================================

variable "rails_env" {
  description = "Rails environment"
  type        = string
  default     = "staging"
}

variable "rails_max_threads" {
  description = "Rails max threads"
  type        = number
  default     = 5
}

# ============================================================================
# Auto-Scaling
# ============================================================================

variable "cpu_target_value" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 80
}

# ============================================================================
# Additional Environment Variables
# ============================================================================

variable "additional_env_vars" {
  description = "Additional environment variables for the application"
  type        = map(string)
  default     = {}
}

# ============================================================================
# Admin Tools (pgAdmin, Redis Commander)
# ============================================================================

variable "enable_admin_tools" {
  description = "Enable pgAdmin and Redis Commander"
  type        = bool
  default     = false
}

variable "pgadmin_email" {
  description = "pgAdmin login email"
  type        = string
  default     = "admin@edugami.pro"
}

variable "pgadmin_password" {
  description = "pgAdmin login password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "redis_commander_user" {
  description = "Redis Commander HTTP basic auth username"
  type        = string
  default     = "admin"
}

variable "redis_commander_password" {
  description = "Redis Commander HTTP basic auth password"
  type        = string
  sensitive   = true
  default     = ""
}
