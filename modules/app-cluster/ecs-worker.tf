# ============================================================================
# ECS Worker Service - Sidekiq (Spot Fargate for ~70% savings)
# ============================================================================
# Worker service runs on FARGATE_SPOT for cost optimization
# No load balancer (background jobs only)
# Same Docker image as web, command overridden to run Sidekiq
# ============================================================================

# ============================================================================
# Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "worker"
      image = "${var.ecr_repository_url}:${var.image_tag}" # Same Docker image as web

      # Override command to run Sidekiq (matching Procfile: bundle exec sidekiq -c 3 -t 300)
      command = [
        "bundle", "exec", "sidekiq",
        "-c", tostring(var.sidekiq_concurrency),
        "-t", tostring(var.sidekiq_timeout)
      ]

      # Environment variables from multiple sources:
      # 1. Hardcoded essentials (MALLOC_ARENA_MAX for memory optimization)
      # 2. SSM Parameter Store /edugami/{env}/config/*
      # 3. additional_env_vars from Terraform variables
      environment = concat([
        { name = "MALLOC_ARENA_MAX", value = "2" } # Reduce memory fragmentation
      ], local.ssm_config_env, [for k, v in var.additional_env_vars : { name = k, value = v }])

      # Secrets from SSM Parameter Store /edugami/{env}/config/*
      # All secrets (DATABASE_URL, REDIS_URL, API keys, etc.) come from SSM
      secrets = concat(local.ssm_secrets, [for k, v in var.additional_secrets : { name = k, valueFrom = v }])

      # Sidekiq health check via process presence
      # Using -f flag to search full command line (not just process name)
      # The process name is "bundle" but args contain "sidekiq"
      healthCheck = {
        command     = ["CMD-SHELL", "pgrep -f sidekiq || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Handle SIGTERM gracefully for Spot interruptions
      # Fargate requires stopTimeout < 120 seconds, so cap at 119
      stopTimeout = min(var.sidekiq_timeout + 30, 119)

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-worker"
    Service = "worker"
  })
}

# ============================================================================
# ECS Service (Spot Fargate for ~70% cost savings)
# ============================================================================

resource "aws_ecs_service" "worker" {
  name            = "${local.name_prefix}-worker"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count

  # Use FARGATE_SPOT for cost optimization (~70% savings)
  # Higher weight = preferred; ECS distributes tasks proportionally by weight
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
    base              = 0
  }

  # Fallback to On-Demand if Spot unavailable
  # Non-zero weight enables fallback when FARGATE_SPOT capacity is unavailable
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  # No load balancer for worker (background jobs only)

  # Enable execute command for debugging
  enable_execute_command = true

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-worker"
    Service = "worker"
  })
}
