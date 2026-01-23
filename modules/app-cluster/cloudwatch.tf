# ============================================================================
# CloudWatch Logs and Alarms
# ============================================================================

# ============================================================================
# CloudWatch Log Groups (separados para web y worker)
# ============================================================================

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/${local.name_prefix}/web"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-web-logs"
    Service = "web"
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${local.name_prefix}/worker"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-worker-logs"
    Service = "worker"
  })
}

# ============================================================================
# CloudWatch Alarms - Web Service
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${local.name_prefix}-web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Web service CPU utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.web.name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "web"
  })
}

resource "aws_cloudwatch_metric_alarm" "web_memory_high" {
  alarm_name          = "${local.name_prefix}-web-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Web service memory utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.web.name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "web"
  })
}

# ============================================================================
# CloudWatch Alarms - Worker Service
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "worker_cpu_high" {
  alarm_name          = "${local.name_prefix}-worker-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Worker service CPU utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.worker.name
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "worker"
  })
}

# ============================================================================
# CloudWatch Alarms - RDS
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "db_cpu_high" {
  alarm_name          = "${local.name_prefix}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "database"
  })
}

resource "aws_cloudwatch_metric_alarm" "db_storage_low" {
  alarm_name          = "${local.name_prefix}-db-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5GB in bytes
  alarm_description   = "RDS free storage space is low"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "database"
  })
}

# ============================================================================
# CloudWatch Alarms - Redis
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  alarm_name          = "${local.name_prefix}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Redis memory utilization is too high"

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.redis.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
  ok_actions    = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = merge(local.common_tags, {
    Service = "redis"
  })
}
