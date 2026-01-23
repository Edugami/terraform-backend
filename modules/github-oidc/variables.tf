# ============================================================================
# GitHub OIDC Module Variables
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  type        = string
}
