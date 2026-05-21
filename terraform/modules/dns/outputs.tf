output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = null
}

output "name_servers" {
  description = "Route 53 name servers for NS delegation"
  value       = []
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = null
}
