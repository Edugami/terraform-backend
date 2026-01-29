# ============================================================================
# Outputs for SSO Identity Center Module
# ============================================================================

output "permission_set_arn" {
  description = "ARN of the SSO permission set"
  value       = aws_ssoadmin_permission_set.readonly.arn
}

output "permission_set_name" {
  description = "Name of the SSO permission set (used in AWS CLI profile configuration)"
  value       = aws_ssoadmin_permission_set.readonly.name
}

output "sso_instance_arn" {
  description = "ARN of the SSO instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

output "assigned_users" {
  description = "List of usernames assigned to the permission set (individual assignments)"
  value       = var.sso_users
}

output "assigned_groups" {
  description = "List of group names assigned to the permission set (group assignments)"
  value       = var.sso_groups
}

output "sso_start_url" {
  description = "SSO start URL for user login - Check AWS Console: IAM Identity Center > Dashboard for actual URL"
  value       = "Check AWS Console: IAM Identity Center > Settings > Identity source to find your SSO start URL (format: https://d-xxxxxxxxxx.awsapps.com/start)"
}

output "aws_account_id" {
  description = "AWS Account ID where permission set is assigned"
  value       = data.aws_caller_identity.current.account_id
}

output "session_duration" {
  description = "Session duration configured for this permission set"
  value       = var.session_duration
}

output "readonly_policy_arn" {
  description = "ARN of the IAM policy attached to the permission set"
  value       = aws_iam_policy.readonly_access.arn
}

output "readonly_policy_name" {
  description = "Name of the IAM policy attached to the permission set"
  value       = aws_iam_policy.readonly_access.name
}
