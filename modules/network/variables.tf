# ============================================================================
# Network Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
