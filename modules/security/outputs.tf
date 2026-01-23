# ============================================================================
# Security Module Outputs
# ============================================================================

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "app_dev_sg_id" {
  description = "ID of the DEV application security group"
  value       = aws_security_group.app_dev.id
}

output "app_prod_sg_id" {
  description = "ID of the PROD application security group"
  value       = aws_security_group.app_prod.id
}

output "db_dev_sg_id" {
  description = "ID of the DEV database security group"
  value       = aws_security_group.db_dev.id
}

output "db_prod_sg_id" {
  description = "ID of the PROD database security group"
  value       = aws_security_group.db_prod.id
}
