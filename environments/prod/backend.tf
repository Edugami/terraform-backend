# ============================================================================
# Terraform Backend Configuration - PROD Environment
# ============================================================================

terraform {
  backend "s3" {
    bucket         = "edugami-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "edugami-terraform-locks"
  }
}
