# ============================================================================
# Monitoring Module Variables
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "edugami"
}

# ============================================================================
# Email Notifications
# ============================================================================

variable "alert_emails" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

# ============================================================================
# Slack Integration (AWS Chatbot)
# ============================================================================

variable "enable_slack_notifications" {
  description = "Enable Slack notifications via AWS Chatbot"
  type        = bool
  default     = false
}

variable "slack_workspace_id" {
  description = "Slack workspace ID (from AWS Chatbot console after authorizing)"
  type        = string
  default     = ""
}

variable "slack_channel_id" {
  description = "Slack channel ID (right-click channel in Slack > View channel details)"
  type        = string
  default     = ""
}
