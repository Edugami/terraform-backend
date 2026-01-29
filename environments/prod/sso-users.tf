# ============================================================================
# AWS SSO (IAM Identity Center) - Read-Only Users for PROD
# ============================================================================
# This configures AWS SSO with temporary credentials that expire every 8 hours
#
# PREREQUISITES (Manual Setup Required - One Time Only):
# 1. Enable AWS Organizations in AWS Console
# 2. Enable IAM Identity Center in us-east-1 region
# 3. Create SSO users in Identity Center (Console or CLI)
#
# SECURITY NOTES FOR PRODUCTION:
# - Consider shorter session duration (PT4H instead of PT8H)
# - Require MFA for all users (Settings in IAM Identity Center)
# - Review CloudTrail logs regularly for SSO activity
# - Limit sso_users list to only essential personnel
# ============================================================================

module "sso_readonly" {
  source = "../../modules/sso-identity-center"

  project_name = var.project_name
  environment  = var.environment

  # ========================================================================
  # OPTION A: Group-Based Assignment (RECOMMENDED for teams)
  # ========================================================================
  # PRODUCTION: Be selective about who gets access
  # Consider creating separate groups:
  # - "Developers" (basic read access)
  # - "SRE-Team" (broader read access for oncall)
  # - "QA-Team" (testing and validation)
  sso_groups = [
    # Add production groups here after validating in DEV
    # Example: "Developers"
  ]

  # ========================================================================
  # OPTION B: Individual User Assignment (for specific cases)
  # ========================================================================
  # For production, prefer groups for easier audit trail
  sso_users = [
    # Add individual users only if they need access outside of groups
  ]

  # Session duration for PROD: Consider shorter duration for better security
  # PT4H = 4 hours, PT8H = 8 hours (ISO-8601 format)
  session_duration = "PT8H" # Consider PT4H for production
}

# ============================================================================
# Outputs - SSO Configuration Info
# ============================================================================

output "sso_readonly_info" {
  description = "SSO configuration information for users"
  value = {
    permission_set_name = module.sso_readonly.permission_set_name
    assigned_groups     = module.sso_readonly.assigned_groups
    assigned_users      = module.sso_readonly.assigned_users
    session_duration    = module.sso_readonly.session_duration
    sso_start_url       = module.sso_readonly.sso_start_url
    aws_account_id      = module.sso_readonly.aws_account_id

    # Instructions for users
    cli_setup_command = "aws configure sso"
    login_command     = "aws sso login --profile edugami-prod"

    # Security reminder
    security_note = "PRODUCTION access - Review audit logs regularly. Require MFA in IAM Identity Center settings."
  }
}

# ============================================================================
# Usage Instructions for PRODUCTION Access
# ============================================================================
#
# FOR USERS - First Time Setup:
# ------------------------------
# 1. Validate SSO access in DEV environment first
# 2. Use same SSO credentials (single Identity Store)
# 3. Configure separate profile: aws configure sso
#    - Profile name: edugami-prod (different from dev)
# 4. Login: aws sso login --profile edugami-prod
#
# FOR USERS - Daily Usage:
# -------------------------
# export AWS_PROFILE=edugami-prod
# aws sso login
# aws ecs describe-services ...
#
# FOR ADMINS - Security Checklist:
# ---------------------------------
# □ Enable MFA requirement in IAM Identity Center settings
# □ Review sso_users list quarterly
# □ Monitor CloudTrail for unusual SSO activity
# □ Consider session_duration = "PT4H" for tighter security
# □ Document who has production access and why
# ============================================================================
