# ============================================================================
# AWS SSO (IAM Identity Center) - Read-Only Users for DEV
# ============================================================================
# This configures AWS SSO with temporary credentials that expire every 8 hours
#
# PREREQUISITES (Manual Setup Required - One Time Only):
# 1. Enable AWS Organizations in AWS Console
# 2. Enable IAM Identity Center in us-east-1 region
# 3. Create SSO users in Identity Center (Console or CLI)
#
# USER SETUP:
# - Each user receives an email invitation to set up password
# - Users configure AWS CLI with: aws configure sso
# - Users login with: aws sso login --profile edugami-dev
# - Credentials auto-expire after 8 hours (more secure than permanent keys)
#
# BENEFITS:
# - Temporary credentials (auto-expire after session duration)
# - No permanent access keys to manage or rotate
# - Centralized user management
# - Multi-account ready for future expansion
# ============================================================================

module "sso_readonly" {
  source = "../../modules/sso-identity-center"

  project_name = var.project_name
  environment  = var.environment

  # ========================================================================
  # OPTION A: Group-Based Assignment (RECOMMENDED for teams)
  # ========================================================================
  # Assign permissions to SSO groups. Users added to these groups
  # automatically get access. Better for managing teams.
  #
  # Steps:
  # 1. Create group in IAM Identity Center: Groups → Create group
  # 2. Add users to group: Groups → [group] → Add users
  # 3. Add group name to sso_groups list below
  # 4. terraform apply
  sso_groups = [
    "ReadOnly" # All developers get read-only access to DEV
  ]

  # ========================================================================
  # OPTION B: Individual User Assignment (for specific cases)
  # ========================================================================
  # Assign permissions directly to individual users.
  # Use this for exceptions or when you need granular control.
  #
  # NOTE: Users in groups above don't need to be listed here
  sso_users = [
    # "claguirre"  # Commented out - now part of Developers group
  ]

  # Session duration: PT8H = 8 hours, PT4H = 4 hours (ISO-8601 format)
  # After this time, users must re-authenticate with: aws sso login
  session_duration = "PT8H"
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
    login_command     = "aws sso login --profile edugami-dev"
  }
}

# ============================================================================
# Usage Instructions (displayed after terraform apply)
# ============================================================================
#
# FOR USERS - First Time Setup:
# ------------------------------
# 1. Check email for "Invitation to join AWS Single Sign-On"
# 2. Click link to set password and configure MFA
# 3. Install/update AWS CLI v2: https://aws.amazon.com/cli/
# 4. Run: aws configure sso
#    - SSO start URL: [see output above]
#    - SSO region: us-east-1
#    - CLI profile name: edugami-dev
# 5. Run: aws sso login --profile edugami-dev
# 6. Test: aws ecs list-clusters --profile edugami-dev
#
# FOR USERS - Daily Usage:
# -------------------------
# export AWS_PROFILE=edugami-dev
# aws sso login                    # Login (opens browser)
# aws ecs describe-services ...    # Use AWS CLI normally
# aws logs tail /ecs/edugami ...   # Credentials valid for 8 hours
#
# FOR ADMINS - Add New Users:
# ---------------------------
# 1. Create user in IAM Identity Center (Console)
# 2. Add username to sso_users list above
# 3. Run: terraform apply
# 4. User receives email invitation
# ============================================================================
