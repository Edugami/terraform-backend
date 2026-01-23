# ============================================================================
# Security Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}
