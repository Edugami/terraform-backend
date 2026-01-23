# ============================================================================
# Monitoring Module - SNS Topics and AWS Chatbot (Slack)
# ============================================================================
# Centralized alerting infrastructure for CloudWatch alarms
# ============================================================================

locals {
  name_prefix = "${var.project_name}-monitoring"
}

# ============================================================================
# SNS Topic for CloudWatch Alarms
# ============================================================================

resource "aws_sns_topic" "alarms" {
  name = "${local.name_prefix}-alarms"

  tags = {
    Name = "${local.name_prefix}-alarms"
  }
}

# SNS Topic Policy - Allow CloudWatch to publish
resource "aws_sns_topic_policy" "alarms" {
  arn = aws_sns_topic.alarms.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarms"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alarms.arn
      }
    ]
  })
}

# ============================================================================
# Email Subscriptions
# ============================================================================

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# ============================================================================
# AWS Chatbot - Slack Integration
# ============================================================================
# Note: Before using this, you must:
# 1. Go to AWS Chatbot console and click "Configure new client"
# 2. Select Slack and authorize AWS Chatbot in your Slack workspace
# 3. Get the Workspace ID from the AWS Chatbot console
# 4. Get the Channel ID from Slack (right-click channel > View channel details)
# ============================================================================

# IAM Role for AWS Chatbot
resource "aws_iam_role" "chatbot" {
  count = var.enable_slack_notifications ? 1 : 0

  name = "${local.name_prefix}-chatbot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-chatbot-role"
  }
}

# IAM Policy for Chatbot - Read-only CloudWatch access
resource "aws_iam_role_policy" "chatbot" {
  count = var.enable_slack_notifications ? 1 : 0

  name = "${local.name_prefix}-chatbot-policy"
  role = aws_iam_role.chatbot[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# AWS Chatbot Slack Channel Configuration
resource "awscc_chatbot_slack_channel_configuration" "alerts" {
  count = var.enable_slack_notifications ? 1 : 0

  configuration_name = "${local.name_prefix}-slack"
  iam_role_arn       = aws_iam_role.chatbot[0].arn
  slack_workspace_id = var.slack_workspace_id
  slack_channel_id   = var.slack_channel_id

  sns_topic_arns = [aws_sns_topic.alarms.arn]

  logging_level = "INFO"

  tags = [
    {
      key   = "Name"
      value = "${local.name_prefix}-slack"
    }
  ]
}
