# ============================================================================
# Terraform Backend Configuration - Shared Infrastructure
# ============================================================================
# Run bootstrap/main.tf FIRST to create the S3 bucket and DynamoDB table
# ============================================================================

terraform {
  backend "s3" {
    bucket         = "edugami-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "edugami-terraform-locks"
  }
}
