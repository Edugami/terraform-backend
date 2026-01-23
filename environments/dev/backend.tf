# ============================================================================
# Terraform Backend Configuration - DEV Environment
# ============================================================================

terraform {
  backend "s3" {
    bucket         = "edugami-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "edugami-terraform-locks"
  }
}
