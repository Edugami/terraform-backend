# ============================================================================
# Admin Tools - pgAdmin & Redis Commander
# ============================================================================
# Web UIs for database administration
# Protected behind ALB with basic auth
# Credentials stored in SSM Parameter Store
# ============================================================================

# ============================================================================
# SSM Parameters for Admin Tools Credentials
# ============================================================================

data "aws_ssm_parameter" "pgadmin_password" {
  count = var.enable_admin_tools ? 1 : 0
  name  = "/edugami/${var.environment}/admin/pgadmin_password"
}

data "aws_ssm_parameter" "redis_commander_password" {
  count = var.enable_admin_tools ? 1 : 0
  name  = "/edugami/${var.environment}/admin/redis_password"
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

resource "aws_cloudwatch_log_group" "pgadmin" {
  name              = "/ecs/${local.name_prefix}/pgadmin"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "redis_commander" {
  name              = "/ecs/${local.name_prefix}/redis-commander"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = local.common_tags
}

# ============================================================================
# pgAdmin Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "pgadmin" {
  count = var.enable_admin_tools ? 1 : 0

  family                   = "${local.name_prefix}-pgadmin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "pgadmin"
      image = "dpage/pgadmin4:latest"

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PGADMIN_DEFAULT_EMAIL", value = var.pgadmin_email },
        { name = "PGADMIN_DEFAULT_PASSWORD", value = data.aws_ssm_parameter.pgadmin_password[0].value },
        { name = "PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION", value = "False" },
        { name = "PGADMIN_CONFIG_WTF_CSRF_ENABLED", value = "False" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.pgadmin.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pgadmin"
    Service = "pgadmin"
  })
}

# ============================================================================
# Redis Commander Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "redis_commander" {
  count = var.enable_admin_tools ? 1 : 0

  family                   = "${local.name_prefix}-redis-commander"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "redis-commander"
      image = "rediscommander/redis-commander:latest"

      portMappings = [
        {
          containerPort = 8081
          hostPort      = 8081
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
        { name = "REDIS_PORT", value = "6379" },
        { name = "HTTP_USER", value = var.redis_commander_user },
        { name = "HTTP_PASSWORD", value = data.aws_ssm_parameter.redis_commander_password[0].value }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.redis_commander.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-redis-commander"
    Service = "redis-commander"
  })
}

# ============================================================================
# pgAdmin ECS Service
# ============================================================================

resource "aws_ecs_service" "pgadmin" {
  count = var.enable_admin_tools ? 1 : 0

  name            = "${local.name_prefix}-pgadmin"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.pgadmin[0].arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pgadmin[0].arn
    container_name   = "pgadmin"
    container_port   = 80
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pgadmin"
    Service = "pgadmin"
  })
}

# ============================================================================
# Redis Commander ECS Service
# ============================================================================

resource "aws_ecs_service" "redis_commander" {
  count = var.enable_admin_tools ? 1 : 0

  name            = "${local.name_prefix}-redis-commander"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.redis_commander[0].arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.app_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.redis_commander[0].arn
    container_name   = "redis-commander"
    container_port   = 8081
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-redis-commander"
    Service = "redis-commander"
  })
}

# ============================================================================
# Target Groups
# ============================================================================

resource "aws_lb_target_group" "pgadmin" {
  count = var.enable_admin_tools ? 1 : 0

  name        = "${local.name_prefix}-pgadmin-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 30
    interval            = 60
    path                = "/misc/ping"
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pgadmin-tg"
  })
}

resource "aws_lb_target_group" "redis_commander" {
  count = var.enable_admin_tools ? 1 : 0

  name        = "${local.name_prefix}-redis-cmd-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 30
    interval            = 60
    path                = "/"
    matcher             = "200,401" # 401 is expected with basic auth
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-cmd-tg"
  })
}

# ============================================================================
# ALB Listener Rules
# ============================================================================

resource "aws_lb_listener_rule" "pgadmin" {
  count = var.enable_admin_tools ? 1 : 0

  listener_arn = var.https_listener_arn
  priority     = var.environment == "dev" ? 10 : 11

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pgadmin[0].arn
  }

  condition {
    host_header {
      values = ["pgadmin-${var.environment}.edugami.pro"]
    }
  }
}

resource "aws_lb_listener_rule" "redis_commander" {
  count = var.enable_admin_tools ? 1 : 0

  listener_arn = var.https_listener_arn
  priority     = var.environment == "dev" ? 12 : 13

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.redis_commander[0].arn
  }

  condition {
    host_header {
      values = ["redis-${var.environment}.edugami.pro"]
    }
  }
}
