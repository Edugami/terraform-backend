# ============================================================================
# App-Cluster Module Outputs
# ============================================================================

# ============================================================================
# ECS Services
# ============================================================================

output "web_service_name" {
  description = "Name of the web ECS service"
  value       = aws_ecs_service.web.name
}

output "web_service_id" {
  description = "ID of the web ECS service"
  value       = aws_ecs_service.web.id
}

output "worker_service_name" {
  description = "Name of the worker ECS service"
  value       = aws_ecs_service.worker.name
}

output "worker_service_id" {
  description = "ID of the worker ECS service"
  value       = aws_ecs_service.worker.id
}

# ============================================================================
# RDS
# ============================================================================

output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS address (host only)"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

# ============================================================================
# Redis
# ============================================================================

output "redis_endpoint" {
  description = "Redis endpoint address"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.port
}

output "redis_connection_string" {
  description = "Redis connection string for Sidekiq"
  value       = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/0"
}

# ============================================================================
# CloudWatch
# ============================================================================

output "web_log_group_name" {
  description = "CloudWatch log group name for web service"
  value       = aws_cloudwatch_log_group.web.name
}

output "web_log_group_arn" {
  description = "CloudWatch log group ARN for web service"
  value       = aws_cloudwatch_log_group.web.arn
}

output "worker_log_group_name" {
  description = "CloudWatch log group name for worker service"
  value       = aws_cloudwatch_log_group.worker.name
}

output "worker_log_group_arn" {
  description = "CloudWatch log group ARN for worker service"
  value       = aws_cloudwatch_log_group.worker.arn
}

# ============================================================================
# Secrets (now managed via SSM Parameter Store)
# ============================================================================
# All secrets are in SSM at /edugami/{environment}/config/

# ============================================================================
# IAM
# ============================================================================

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}
