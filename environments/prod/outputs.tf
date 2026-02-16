# ============================================================================
# PROD Environment Outputs
# ============================================================================

output "web_service_name" {
  description = "Name of the web ECS service"
  value       = module.app_cluster.web_service_name
}

output "worker_service_name" {
  description = "Name of the worker ECS service"
  value       = module.app_cluster.worker_service_name
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.app_cluster.rds_endpoint
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.app_cluster.redis_endpoint
}

output "web_log_group_name" {
  description = "CloudWatch log group name for web service"
  value       = module.app_cluster.web_log_group_name
}

output "worker_log_group_name" {
  description = "CloudWatch log group name for worker service"
  value       = module.app_cluster.worker_log_group_name
}

output "alb_dns_name" {
  description = "ALB DNS name (from shared infrastructure)"
  value       = data.terraform_remote_state.shared.outputs.alb_dns_name
}

output "app_url" {
  description = "Application URL"
  value       = "https://prod.edugami.pro"
}

# ============================================================================
# On-Demand Task Outputs
# ============================================================================
# Use this task definition for both interactive tasks and EventBridge schedules

output "ondemand_task_definition_family" {
  description = "Family name for on-demand tasks (use for interactive and scheduled tasks)"
  value       = module.app_cluster.ondemand_task_definition_family
}

output "ondemand_task_definition_arn" {
  description = "ARN for on-demand task definition (use in EventBridge Scheduler UI)"
  value       = module.app_cluster.ondemand_task_definition_arn
}

output "ondemand_log_group_name" {
  description = "CloudWatch log group for on-demand tasks"
  value       = module.app_cluster.ondemand_log_group_name
}

output "private_app_subnet_ids" {
  description = "Private subnet IDs (use in EventBridge network configuration)"
  value       = data.terraform_remote_state.shared.outputs.private_app_subnet_ids
}

output "app_security_group_id" {
  description = "App security group ID (use in EventBridge network configuration)"
  value       = data.terraform_remote_state.shared.outputs.app_prod_sg_id
}

