output "repository_urls" {
  description = "Map of service_name to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of service_name to ECR repository ARN"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

output "repository_names" {
  description = "Map of service_name to ECR repository name (e.g. petclinic-dev/config-server)"
  value       = { for k, v in aws_ecr_repository.services : k => v.name }
}
