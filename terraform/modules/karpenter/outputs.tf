output "karpenter_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = null
}

output "karpenter_queue_name" {
  description = "SQS interruption queue name"
  value       = null
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter-launched nodes"
  value       = null
}
