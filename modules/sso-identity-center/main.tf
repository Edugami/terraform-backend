# ============================================================================
# AWS SSO (IAM Identity Center) - Read-Only Access
# ============================================================================
# This module configures AWS SSO permission sets that reference existing
# IAM policies created by the readonly-users module.
#
# Benefits over traditional IAM users:
# - Temporary credentials that auto-expire (default: 8 hours)
# - Centralized user management
# - Automatic credential rotation
# - Better security posture (no long-lived access keys)
# - Multi-account ready
# ============================================================================

# ============================================================================
# Data Sources - SSO Instance and Identity Store
# ============================================================================

# Get the SSO instance (must be manually enabled first in AWS Console)
data "aws_ssoadmin_instances" "main" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

# ============================================================================
# IAM Policy - Read-Only Permissions
# ============================================================================

# Create the readonly policy directly in this module
# No need for separate readonly-users module
resource "aws_iam_policy" "readonly_access" {
  name        = "${var.project_name}-${var.environment}-readonly-policy"
  description = "Read-only access to view ECS tasks, logs, and infrastructure status"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECS Read-Only
      {
        Sid    = "ECSReadOnly"
        Effect = "Allow"
        Action = [
          "ecs:Describe*",
          "ecs:List*",
          "ecs:Get*"
        ]
        Resource = "*"
      },
      # CloudWatch Logs Read-Only
      {
        Sid    = "CloudWatchLogsReadOnly"
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:FilterLogEvents",
          "logs:TestMetricFilter"
        ]
        Resource = "*"
      },
      # CloudWatch Metrics Read-Only
      {
        Sid    = "CloudWatchMetricsReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      # RDS Read-Only (status only, no data access)
      {
        Sid    = "RDSReadOnly"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:List*"
        ]
        Resource = "*"
      },
      # ElastiCache Read-Only
      {
        Sid    = "ElastiCacheReadOnly"
        Effect = "Allow"
        Action = [
          "elasticache:Describe*",
          "elasticache:List*"
        ]
        Resource = "*"
      },
      # Application Load Balancer Read-Only
      {
        Sid    = "ALBReadOnly"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      },
      # VPC/Network Read-Only
      {
        Sid    = "VPCReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      # SSM Parameter Store Read-Only (to view config)
      {
        Sid    = "SSMReadOnly"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.project_name}/${var.environment}/*",
          "arn:aws:ssm:*:*:parameter/${var.project_name}/shared/*"
        ]
      },
      # KMS Read-Only (to decrypt SSM parameters)
      {
        Sid    = "KMSDecryptReadOnly"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.*.amazonaws.com"
          }
        }
      },
      # ECR Read-Only (to view images)
      {
        Sid    = "ECRReadOnly"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Type        = "ReadOnlySSO"
  }
}

# ============================================================================
# Data Source - Get Current AWS Account ID
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# SSO Permission Set
# ============================================================================

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "${var.project_name}-${var.environment}-readonly"
  description      = "Read-only access to view ECS tasks, logs, and infrastructure status via SSO"
  instance_arn     = local.sso_instance_arn
  session_duration = var.session_duration

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Type        = "ReadOnlySSO"
  }
}

# ============================================================================
# Attach Customer-Managed IAM Policy to Permission Set
# ============================================================================

# Attach the readonly policy to the SSO permission set
resource "aws_ssoadmin_customer_managed_policy_attachment" "readonly_policy" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  customer_managed_policy_reference {
    name = aws_iam_policy.readonly_access.name
    path = "/"
  }
}

# ============================================================================
# Look Up SSO Users (Individual Assignment - Optional)
# ============================================================================

# Look up each user in the Identity Store by username
data "aws_identitystore_user" "sso_users" {
  for_each = toset(var.sso_users)

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = each.value
    }
  }
}

# ============================================================================
# Look Up SSO Groups (Group-Based Assignment - Recommended)
# ============================================================================

# Look up each group in the Identity Store by group name
data "aws_identitystore_group" "sso_groups" {
  for_each = toset(var.sso_groups)

  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

# ============================================================================
# Assign Users to Permission Set (Individual)
# ============================================================================

# Assign each SSO user to the readonly permission set for this account
resource "aws_ssoadmin_account_assignment" "user_assignments" {
  for_each = data.aws_identitystore_user.sso_users

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = each.value.user_id
  principal_type = "USER"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}

# ============================================================================
# Assign Groups to Permission Set (Recommended for Teams)
# ============================================================================

# Assign each SSO group to the readonly permission set for this account
resource "aws_ssoadmin_account_assignment" "group_assignments" {
  for_each = data.aws_identitystore_group.sso_groups

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn

  principal_id   = each.value.group_id
  principal_type = "GROUP"

  target_id   = data.aws_caller_identity.current.account_id
  target_type = "AWS_ACCOUNT"
}
