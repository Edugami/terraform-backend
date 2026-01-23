# ============================================================================
# ECS Cluster Module - Shared ECS Cluster
# ============================================================================
# Single ECS cluster shared between DEV and PROD
# Supports both FARGATE (On-Demand) and FARGATE_SPOT capacity providers
# ============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.project_name}-cluster"
    Environment = "shared"
  }
}

# ============================================================================
# Capacity Providers - FARGATE and FARGATE_SPOT
# ============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }
}
