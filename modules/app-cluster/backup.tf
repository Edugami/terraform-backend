# ============================================================================
# AWS Backup — RDS database copies retained 90 days (prod only)
# ============================================================================
# RDS native backup_retention_period maxes out at 35 days.
# AWS Backup is required for the 3-month retention requirement.
# Only deployed in prod (this module is instantiated per environment).
# ============================================================================

# ============================================================================
# Backup Vault
# ============================================================================

resource "aws_backup_vault" "main" {
  name = "${local.name_prefix}-backup-vault"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-vault"
  })
}

# ============================================================================
# IAM Role for AWS Backup
# ============================================================================

resource "aws_iam_role" "backup" {
  name = "${local.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# ============================================================================
# Backup Plan — daily snapshot, 90-day retention
# ============================================================================

resource "aws_backup_plan" "main" {
  name = "${local.name_prefix}-backup-plan"

  rule {
    rule_name         = "daily-90-day-retention"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)" # Daily at 05:00 UTC

    lifecycle {
      delete_after = 90
    }
  }

  tags = local.common_tags
}

# ============================================================================
# Backup Selection — RDS instance
# ============================================================================

resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${local.name_prefix}-rds-backup"
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.main.arn,
  ]
}
