# ============================================================================
# RDS PostgreSQL Database
# ============================================================================
# Aurora-ready architecture (can migrate to Aurora later)
# Uses t4g (Graviton) instances for cost savings
# ============================================================================

# ============================================================================
# Random Password (fallback when var.db_password not provided)
# ============================================================================
# Generated only on initial creation; ignored thereafter via lifecycle block.
# After RDS creation, manage password via SSM Parameter Store / DATABASE_URL.
# ============================================================================

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" # RDS-compatible special chars
}

# ============================================================================
# IAM Role for Enhanced Monitoring
# ============================================================================

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# RDS Subnet Group
# ============================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet"
  description = "Database subnet group for ${var.environment}"
  subnet_ids  = var.private_db_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet"
  })
}

# ============================================================================
# RDS Parameter Group (PostgreSQL optimized for Rails)
# ============================================================================

resource "aws_db_parameter_group" "postgresql" {
  name        = "${local.name_prefix}-pg-params"
  family      = "postgres16"
  description = "PostgreSQL parameters for ${var.environment}"

  # Rails-optimized parameters
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pg-params"
  })
}

# ============================================================================
# RDS PostgreSQL Instance
# ============================================================================

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-db"

  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2 # Enable storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = replace("${var.db_name}_${var.environment}", "-", "_")
  username = var.db_username
  # Use provided password or fall back to generated random password
  password = coalesce(var.db_password, random_password.db.result)

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgresql.name

  multi_az                  = var.db_multi_az
  publicly_accessible       = false
  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null

  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Performance Insights (free tier available)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Enhanced Monitoring (60 second granularity)
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Enable deletion protection for production
  deletion_protection = var.environment == "prod" ? true : false

  # Enable automatic minor version upgrades
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })

  lifecycle {
    # Prevent accidental destruction of database
    # Note: prevent_destroy cannot be dynamic in Terraform (must be literal bool)
    # For dev teardown: temporarily set to false, or use terraform state rm
    # AWS-level protection is handled by deletion_protection (true for prod, false for dev)
    prevent_destroy = true

    # Ignore password changes after initial creation
    # Password is managed via SSM Parameter Store in DATABASE_URL
    ignore_changes = [password]
  }
}
