# ============================================================================
# Auto-Scaling Configuration (Target Tracking)
# ============================================================================
# Automatic scaling based on CPU and Memory utilization
# Web service also scales on ALB request count
# ============================================================================

# ============================================================================
# Web Service Auto-Scaling
# ============================================================================

resource "aws_appautoscaling_target" "web" {
  max_capacity       = var.web_max_count
  min_capacity       = var.web_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Web CPU Target Tracking
resource "aws_appautoscaling_policy" "web_cpu" {
  name               = "${local.name_prefix}-web-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Web Memory Target Tracking
resource "aws_appautoscaling_policy" "web_memory" {
  name               = "${local.name_prefix}-web-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ============================================================================
# Worker Service Auto-Scaling
# ============================================================================

resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.worker_max_count
  min_capacity       = var.worker_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Worker CPU Target Tracking
resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${local.name_prefix}-worker-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Worker Memory Target Tracking
resource "aws_appautoscaling_policy" "worker_memory" {
  name               = "${local.name_prefix}-worker-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
