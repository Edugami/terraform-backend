# ============================================================================
# ACM Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
  default     = "edugami.pro"
}

# Optional: Uncomment if using Route53 for DNS validation
# variable "route53_zone_id" {
#   description = "Route53 hosted zone ID for DNS validation"
#   type        = string
#   default     = ""
# }
