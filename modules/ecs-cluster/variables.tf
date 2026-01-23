# ============================================================================
# ECS Cluster Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}
