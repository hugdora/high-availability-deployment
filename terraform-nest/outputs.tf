output "alb_dns_name" {
  description = "Paste into browser to access the Nest app"
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (injected into EC2 .env via user_data)"
  value       = module.rds.db_endpoint
}

output "asg_name" {
  description = "Auto Scaling Group name — use for CLI verification"
  value       = module.asg.asg_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret used by this deployment"
  value       = data.aws_secretsmanager_secret.app.arn
}

