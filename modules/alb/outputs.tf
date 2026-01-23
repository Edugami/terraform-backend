# ============================================================================
# ALB Module Outputs
# ============================================================================

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "dev_target_group_arn" {
  description = "ARN of the DEV target group"
  value       = aws_lb_target_group.dev.arn
}

output "prod_target_group_arn" {
  description = "ARN of the PROD target group"
  value       = aws_lb_target_group.prod.arn
}
