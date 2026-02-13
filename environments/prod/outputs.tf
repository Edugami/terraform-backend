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
