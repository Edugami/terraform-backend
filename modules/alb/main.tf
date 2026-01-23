# ============================================================================
# ALB Module - Shared Application Load Balancer with Host-Based Routing
# ============================================================================
# Single ALB shared between DEV and PROD
# Routes traffic based on Host header (dev.edugami.pro vs www.edugami.pro)
# ============================================================================

# ============================================================================
# Application Load Balancer
# ============================================================================

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  # Security hardening: drop malformed HTTP headers to mitigate request smuggling
  drop_invalid_header_fields = true

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = "shared"
  }
}

# ============================================================================
# HTTPS Listener (port 443)
# ============================================================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  # Default action - return 404 for unknown hosts
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# ============================================================================
# HTTP Listener (redirect to HTTPS)
# ============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ============================================================================
# DEV Target Group
# ============================================================================

resource "aws_lb_target_group" "dev" {
  name        = "${var.project_name}-dev-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 30
    interval            = 60
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name        = "${var.project_name}-dev-tg"
    Environment = "dev"
  }
}

# ============================================================================
# PROD Target Group
# ============================================================================

resource "aws_lb_target_group" "prod" {
  name        = "${var.project_name}-prod-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 30
    interval            = 60
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name        = "${var.project_name}-prod-tg"
    Environment = "prod"
  }
}

# ============================================================================
# Host-Based Routing Rules
# ============================================================================

# DEV: dev.edugami.pro
resource "aws_lb_listener_rule" "dev" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev.arn
  }

  condition {
    host_header {
      values = var.dev_host_headers
    }
  }
}

# PROD: www.edugami.pro, edugami.pro
resource "aws_lb_listener_rule" "prod" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod.arn
  }

  condition {
    host_header {
      values = var.prod_host_headers
    }
  }
}
