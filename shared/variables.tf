# ============================================================================
# Shared Infrastructure Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

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

variable "domain_name" {
  description = "Primary domain name for SSL certificate"
  type        = string
  default     = "edugami.pro"
}

variable "dev_host_headers" {
  description = "Host headers for DEV environment"
  type        = list(string)
  default     = ["dev.edugami.pro"]
}

variable "prod_host_headers" {
  description = "Host headers for PROD environment"
  type        = list(string)
  default     = ["edugami.pro", "www.edugami.pro"]
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_alb_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# ============================================================================
# GitHub Actions OIDC
# ============================================================================

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
  default     = "Edugami"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "edugami-platform"
}

# ============================================================================
# Monitoring / Alerting
# ============================================================================

variable "alert_emails" {
  description = "Email addresses to receive alarm notifications"
  type        = list(string)
  default     = ["carlos@edugami.pro"]
}

variable "enable_slack_notifications" {
  description = "Enable Slack notifications via AWS Chatbot"
  type        = bool
  default     = false
}

variable "slack_workspace_id" {
  description = "Slack workspace ID (from AWS Chatbot console)"
  type        = string
  default     = ""
}

variable "slack_channel_id" {
  description = "Slack channel ID for alerts"
  type        = string
  default     = ""
}

# ============================================================================
# WAF (Web Application Firewall)
# ============================================================================

variable "enable_waf" {
  description = "Enable AWS WAF on ALB to protect admin tools with IP allowlist"
  type        = bool
  default     = true
}

variable "admin_allowed_cidrs" {
  description = "CIDR blocks allowed to access admin tools (pgAdmin, Redis Commander). Include corporate/VPN IPs."
  type        = list(string)
  default     = [] # Must be explicitly configured - no default access
}

variable "enable_aws_managed_rules" {
  description = "Enable AWS Managed WAF Rules (recommended for production)"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Max requests per 5-minute period per IP (0 to disable)"
  type        = number
  default     = 2000
}

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}
