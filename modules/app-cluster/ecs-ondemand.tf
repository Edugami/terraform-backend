# ============================================================================
# ECS On-Demand Task - Interactive Rails Container
# ============================================================================
# For running migrations, rails console, debugging, and long-running queries
# Runs on FARGATE (On-Demand) for stability
# No ECS Service - use `aws ecs run-task` to launch instances
# ============================================================================

# ============================================================================
# CloudWatch Logs
# ============================================================================

resource "aws_cloudwatch_log_group" "ondemand" {
  name              = "/ecs/${local.name_prefix}/ondemand"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-ondemand"
    Service = "ondemand"
  })
}

# ============================================================================
# Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "ondemand" {
  family                   = "${local.name_prefix}-ondemand"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ondemand_cpu
  memory                   = var.ondemand_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Ephemeral storage for large logs, temporary files, etc.
  ephemeral_storage {
    size_in_gib = var.ondemand_ephemeral_storage
  }

  container_definitions = jsonencode([
    {
      name  = "ondemand"
      image = "${var.ecr_repository_url}:${var.image_tag}"

      # Keep container running for interactive shell access
      command = ["sleep", "infinity"]

      # No port mappings needed (not receiving HTTP traffic)
      portMappings = []

      # Environment variables from multiple sources:
      # 1. Hardcoded essentials
      # 2. SSM Parameter Store /edugami/{env}/config/*
      # 3. additional_env_vars from Terraform variables
      environment = concat([
        { name = "RAILS_LOG_TO_STDOUT", value = "true" }
      ], local.ssm_config_env, [for k, v in var.additional_env_vars : { name = k, value = v }])

      # Secrets from SSM Parameter Store /edugami/{env}/config/*
      # All secrets (DATABASE_URL, REDIS_URL, API keys, etc.) come from SSM
      secrets = concat(local.ssm_secrets, [for k, v in var.additional_secrets : { name = k, valueFrom = v }])

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ondemand.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Longer stop timeout for migrations that may take time to complete
      stopTimeout = 119

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-ondemand"
    Service = "ondemand"
    Type    = "interactive"
  })
}
