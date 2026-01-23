# ============================================================================
# ElastiCache Redis for Sidekiq
# ============================================================================
# Redis for Sidekiq job queues and Rails caching
# Uses t4g (Graviton) instances for cost savings
# ============================================================================

# ============================================================================
# ElastiCache Subnet Group
# ============================================================================

resource "aws_elasticache_subnet_group" "redis" {
  name        = "${local.name_prefix}-redis-subnet"
  description = "Redis subnet group for ${var.environment}"
  subnet_ids  = var.private_db_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-subnet"
  })
}

# ============================================================================
# ElastiCache Parameter Group
# ============================================================================

resource "aws_elasticache_parameter_group" "redis" {
  name        = "${local.name_prefix}-redis-params"
  family      = "redis7"
  description = "Redis parameters for Sidekiq ${var.environment}"

  # Sidekiq-optimized parameters
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru" # Remove least recently used keys with TTL
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex" # Enable keyspace notifications for expiry events
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-params"
  })
}

# ============================================================================
# ElastiCache Redis Cluster
# ============================================================================

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${local.name_prefix}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.db_security_group_id]

  # Maintenance window
  maintenance_window = "sun:05:00-sun:06:00"

  # Snapshot for production
  snapshot_retention_limit = var.environment == "prod" ? 3 : 0
  snapshot_window          = var.environment == "prod" ? "02:00-03:00" : null

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-redis"
    Service = "sidekiq"
  })
}
