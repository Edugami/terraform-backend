# ============================================================================
# WAF Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

# ============================================================================
# ALB Configuration
# ============================================================================

variable "alb_arn" {
  description = "ARN of the ALB to associate with WAF"
  type        = string
}

# ============================================================================
# Admin Tools IP Allowlist
# ============================================================================

variable "admin_allowed_cidrs" {
  description = "List of CIDR blocks allowed to access admin tools (pgAdmin, Redis Commander). Include your corporate/VPN IP ranges. Use 0.0.0.0/0 to allow all (not recommended for production)."
  type        = list(string)
}

# ============================================================================
# AWS Managed Rules (recommended for production)
# ============================================================================

variable "enable_aws_managed_rules" {
  description = "Enable AWS Managed Rules (Common Rule Set + Known Bad Inputs). Recommended for production."
  type        = bool
  default     = true
}

# ============================================================================
# Rate Limiting
# ============================================================================

variable "rate_limit" {
  description = "Maximum requests per 5-minute period per IP. Set to 0 to disable rate limiting."
  type        = number
  default     = 2000
}

# ============================================================================
# Logging
# ============================================================================

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch (logs blocked requests only)"
  type        = bool
  default     = true
}
