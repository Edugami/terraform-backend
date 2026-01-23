# ============================================================================
# Security Module - Environment-Isolated Security Groups
# ============================================================================
# DEV and PROD are logically isolated through Security Groups
# PROD DB only accepts traffic from PROD App SG (same for DEV)
# ============================================================================

# ============================================================================
# ALB Security Group (Shared)
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = "shared"
  }
}

# ============================================================================
# DEV Application Security Group
# ============================================================================

resource "aws_security_group" "app_dev" {
  name        = "${var.project_name}-app-dev-sg"
  description = "Security group for DEV ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Rails from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "pgAdmin from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Redis Commander from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow internal communication within DEV
  ingress {
    description = "Internal DEV communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-app-dev-sg"
    Environment = "dev"
  }
}

# ============================================================================
# PROD Application Security Group
# ============================================================================

resource "aws_security_group" "app_prod" {
  name        = "${var.project_name}-app-prod-sg"
  description = "Security group for PROD ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Rails from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "pgAdmin from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Redis Commander from ALB"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow internal communication within PROD
  ingress {
    description = "Internal PROD communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-app-prod-sg"
    Environment = "prod"
  }
}

# ============================================================================
# DEV Database Security Group
# CRITICAL: Only accepts traffic from DEV App SG
# ============================================================================

resource "aws_security_group" "db_dev" {
  name        = "${var.project_name}-db-dev-sg"
  description = "Security group for DEV RDS and ElastiCache - ONLY DEV App access"
  vpc_id      = var.vpc_id

  # PostgreSQL - ONLY from DEV App
  ingress {
    description     = "PostgreSQL from DEV App only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_dev.id]
  }

  # Redis - ONLY from DEV App
  ingress {
    description     = "Redis from DEV App only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_dev.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-dev-sg"
    Environment = "dev"
  }
}

# ============================================================================
# PROD Database Security Group
# CRITICAL: Only accepts traffic from PROD App SG
# ============================================================================

resource "aws_security_group" "db_prod" {
  name        = "${var.project_name}-db-prod-sg"
  description = "Security group for PROD RDS and ElastiCache - ONLY PROD App access"
  vpc_id      = var.vpc_id

  # PostgreSQL - ONLY from PROD App
  ingress {
    description     = "PostgreSQL from PROD App only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_prod.id]
  }

  # Redis - ONLY from PROD App
  ingress {
    description     = "Redis from PROD App only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app_prod.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-db-prod-sg"
    Environment = "prod"
  }
}
