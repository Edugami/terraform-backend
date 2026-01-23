# ============================================================================
# ECS Web Service - Rails Application (On-Demand Fargate)
# ============================================================================
# Web service runs on FARGATE (On-Demand) for stability
# Connected to ALB for incoming HTTP traffic
# ============================================================================

# ============================================================================
# Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "web" {
  family                   = "${local.name_prefix}-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.web_cpu
  memory                   = var.web_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "web"
      image = "${var.ecr_repository_url}:${var.image_tag}"

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      command = ["bin/rails", "s", "-b", "0.0.0.0", "-p", "3000"]

      # Environment variables from multiple sources:
      # 1. Hardcoded essentials (PORT, etc.)
      # 2. SSM Parameter Store /edugami/{env}/config/*
      # 3. additional_env_vars from Terraform variables
      environment = concat([
        { name = "PORT", value = "3000" },
        { name = "WEB_CONCURRENCY", value = "2" }
      ], local.ssm_config_env, [for k, v in var.additional_env_vars : { name = k, value = v }])

      # Secrets from SSM Parameter Store /edugami/{env}/config/*
      # All secrets (DATABASE_URL, REDIS_URL, API keys, etc.) come from SSM
      secrets = concat(local.ssm_secrets, [for k, v in var.additional_secrets : { name = k, valueFrom = v }])

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-web"
    Service = "web"
  })
}

# ============================================================================
# ECS Service (On-Demand for stability)
# ============================================================================

resource "aws_ecs_service" "web" {
  name            = "${local.name_prefix}-web"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.web_desired_count

  # Grace period for ALB health checks (Rails needs time to boot)
  health_check_grace_period_seconds = 180

  # On-Demand capacity for stability
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "web"
    container_port   = 3000
  }

  # Enable execute command for debugging
  enable_execute_command = true

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-web"
    Service = "web"
  })
}
