# ============================================================================
# WAF Module Outputs
# ============================================================================

output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.main.id
}

output "ip_set_arn" {
  description = "ARN of the admin tools IPv4 allowlist"
  value       = aws_wafv2_ip_set.admin_allowlist_ipv4.arn
}

output "ip_set_ipv6_arn" {
  description = "ARN of the admin tools IPv6 allowlist"
  value       = aws_wafv2_ip_set.admin_allowlist_ipv6.arn
}
