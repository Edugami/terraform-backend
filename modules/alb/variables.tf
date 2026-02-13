# ============================================================================
# ALB Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "edugami"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "dev_host_headers" {
  description = "Host headers for DEV environment"
  type        = list(string)
  default     = ["dev.edugami.pro"]
}

variable "prod_host_headers" {
  description = "Host headers for PROD environment"
  type        = list(string)
  default     = ["prod.edugami.pro"]
}
