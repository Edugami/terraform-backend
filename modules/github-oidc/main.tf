# ============================================================================
# GitHub Actions OIDC Module
# ============================================================================
# Creates IAM Role for GitHub Actions to deploy to AWS ECS
# Uses OIDC federation (no static credentials needed)
# ============================================================================

# ============================================================================
# GitHub OIDC Identity Provider
# ============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (this is GitHub's official thumbprint)
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# ============================================================================
# IAM Role for GitHub Actions
# ============================================================================

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# ============================================================================
# IAM Policy - ECR Access (Push Images)
# ============================================================================

resource "aws_iam_role_policy" "ecr_access" {
  name = "${var.project_name}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRGetAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

# ============================================================================
# IAM Policy - ECS Access (Update Services)
# ============================================================================

resource "aws_iam_role_policy" "ecs_access" {
  name = "${var.project_name}-github-actions-ecs"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSUpdateService"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "ecs:cluster" = var.ecs_cluster_arn
          }
        }
      },
      {
        Sid    = "ECSClusterAccess"
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters"
        ]
        Resource = var.ecs_cluster_arn
      },
      {
        Sid    = "ECSTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRoleToECS"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*-ecs-*"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
