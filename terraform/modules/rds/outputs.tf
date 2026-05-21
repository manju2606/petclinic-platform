output "endpoint" {
  description = "RDS instance endpoint hostname"
  value       = null
}

output "port" {
  description = "RDS instance port"
  value       = 3306
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = null
}

output "secret_arn" {
  description = "Secrets Manager ARN for RDS master credentials"
  value       = null
  sensitive   = true
}
