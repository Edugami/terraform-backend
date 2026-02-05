# ============================================================================
# AWS WAF Module - ALB Protection with IP Allowlist for Admin Tools
# ============================================================================
# Protects admin tools (pgAdmin, Redis Commander) by restricting access
# to specified IP addresses (corporate/VPN CIDRs)
# ============================================================================

# ============================================================================
# IP Sets for Allowed Admin Access (IPv4 and IPv6)
# ============================================================================

locals {
  # Separate IPv4 and IPv6 CIDRs
  ipv4_cidrs = [for cidr in var.admin_allowed_cidrs : cidr if can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+/[0-9]+$", cidr))]
  ipv6_cidrs = [for cidr in var.admin_allowed_cidrs : cidr if can(regex(":", cidr))]
}

resource "aws_wafv2_ip_set" "admin_allowlist_ipv4" {
  name               = "${var.project_name}-admin-allowlist-ipv4"
  description        = "IPv4 addresses allowed to access admin tools"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = length(local.ipv4_cidrs) > 0 ? local.ipv4_cidrs : ["127.0.0.1/32"]

  tags = {
    Name = "${var.project_name}-admin-allowlist-ipv4"
  }
}

resource "aws_wafv2_ip_set" "admin_allowlist_ipv6" {
  name               = "${var.project_name}-admin-allowlist-ipv6"
  description        = "IPv6 addresses allowed to access admin tools"
  scope              = "REGIONAL"
  ip_address_version = "IPV6"
  addresses          = length(local.ipv6_cidrs) > 0 ? local.ipv6_cidrs : ["::1/128"]

  tags = {
    Name = "${var.project_name}-admin-allowlist-ipv6"
  }
}

# ============================================================================
# WAF Web ACL
# ============================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf-acl"
  description = "WAF ACL for ${var.project_name} ALB - protects admin tools with IP allowlist"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ============================================================================
  # Rule 1: Block admin tools access from non-allowed IPs (IPv4 and IPv6)
  # ============================================================================
  rule {
    name     = "admin-tools-ip-allowlist"
    priority = 1

    action {
      block {}
    }

    statement {
      and_statement {
        # Condition 1: Request is for admin tool hostnames
        statement {
          or_statement {
            statement {
              byte_match_statement {
                search_string = "pgadmin-"
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
                positional_constraint = "STARTS_WITH"
              }
            }
            statement {
              byte_match_statement {
                search_string = "redis-"
                field_to_match {
                  single_header {
                    name = "host"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
                positional_constraint = "STARTS_WITH"
              }
            }
          }
        }

        # Condition 2: IP is NOT in allowlist (check both IPv4 and IPv6)
        statement {
          not_statement {
            statement {
              or_statement {
                statement {
                  ip_set_reference_statement {
                    arn = aws_wafv2_ip_set.admin_allowlist_ipv4.arn
                  }
                }
                statement {
                  ip_set_reference_statement {
                    arn = aws_wafv2_ip_set.admin_allowlist_ipv6.arn
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-admin-tools-blocked"
      sampled_requests_enabled   = true
    }
  }

  # ============================================================================
  # Rule 2: AWS Managed Rules - Common Rule Set (optional but recommended)
  # ============================================================================
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? [1] : []
    content {
      name     = "aws-managed-common-rules"
      priority = 10

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          # Override: Allow large request bodies for image uploads
          # SizeRestrictions_BODY blocks requests >8KB by default
          rule_action_override {
            name = "SizeRestrictions_BODY"
            action_to_use {
              count {} # Count instead of block - allows monitoring without blocking
            }
          }

          # Override: Allow MathML/LaTeX in educational content
          # CrossSiteScripting_BODY blocks MathML namespaces (xmlns="http://www.w3.org/1998/Math/MathML")
          # This is legitimate content in our EdTech platform
          rule_action_override {
            name = "CrossSiteScripting_BODY"
            action_to_use {
              count {} # Count instead of block - Rails has its own XSS protection
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-aws-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================================================
  # Rule 3: AWS Managed Rules - Known Bad Inputs (optional but recommended)
  # ============================================================================
  dynamic "rule" {
    for_each = var.enable_aws_managed_rules ? [1] : []
    content {
      name     = "aws-managed-known-bad-inputs"
      priority = 11

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-aws-bad-inputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # ============================================================================
  # Rule 4: Rate limiting (optional)
  # ============================================================================
  dynamic "rule" {
    for_each = var.rate_limit > 0 ? [1] : []
    content {
      name     = "rate-limit"
      priority = 20

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-rate-limited"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-waf-acl"
  }
}

# ============================================================================
# Associate WAF ACL with ALB
# ============================================================================

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ============================================================================
# CloudWatch Log Group for WAF (optional)
# ============================================================================

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf_logging ? 1 : 0

  name              = "aws-waf-logs-${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "aws-waf-logs-${var.project_name}"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  # Only log blocked requests to reduce costs
  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}
