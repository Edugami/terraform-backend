# ============================================================================
# ACM Module Outputs
# ============================================================================

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.main.status
}

# ============================================================================
# DNS Validation Records - CREATE THESE MANUALLY IN YOUR DNS PROVIDER
# ============================================================================

output "dns_validation_records" {
  description = "DNS records to create manually in your DNS provider for certificate validation"
  value = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}

output "validation_instructions" {
  description = "Instructions for manual DNS validation"
  value       = <<-EOT
    ============================================================================
    MANUAL DNS VALIDATION REQUIRED
    ============================================================================

    1. Run: terraform output dns_validation_records
    2. Create the CNAME records in your DNS provider
    3. Wait 5-30 minutes for AWS to validate
    4. Check status in AWS Console -> Certificate Manager

    The certificate will show as "Issued" once validated.
    ============================================================================
  EOT
}
