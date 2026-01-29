# ============================================================================
# Variables for SSO Identity Center Module
# ============================================================================

variable "project_name" {
  description = "Project name (e.g., edugami)"
  type        = string
}

variable "environment" {
  description = "Environment (dev, prod)"
  type        = string
}

variable "sso_users" {
  description = "List of SSO usernames to grant read-only access (users must already exist in Identity Center). For teams, use sso_groups instead."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for user in var.sso_users : can(regex("^[a-zA-Z0-9+=,.@_-]+$", user))])
    error_message = "User names must contain only alphanumeric characters and +=,.@_-"
  }
}

variable "sso_groups" {
  description = "List of SSO group names to grant read-only access (groups must already exist in Identity Center). Recommended for teams."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for group in var.sso_groups : can(regex("^[a-zA-Z0-9+=,.@_\\- ]+$", group))])
    error_message = "Group names must contain only alphanumeric characters, spaces, and +=,.@_-"
  }
}

variable "session_duration" {
  description = "Maximum session duration in ISO-8601 format (e.g., PT8H for 8 hours, PT4H for 4 hours)"
  type        = string
  default     = "PT8H"

  validation {
    condition     = can(regex("^PT([0-9]|1[0-2])H$", var.session_duration))
    error_message = "Session duration must be in ISO-8601 format between PT1H and PT12H (e.g., PT8H for 8 hours)"
  }
}
