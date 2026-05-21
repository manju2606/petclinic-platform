output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL for IRSA (without https:// prefix)"
  value       = local.oidc_provider_url_stripped
}

output "node_group_name" {
  description = "Managed node group name"
  value       = aws_eks_node_group.this.node_group_name
}

output "node_role_arn" {
  description = "IAM role ARN for EKS nodes (used by Karpenter)"
  value       = aws_iam_role.node.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for the EBS CSI Driver (IRSA)"
  value       = aws_iam_role.ebs_csi.arn
}

output "vpc_cni_role_arn" {
  description = "IAM role ARN for the VPC CNI addon (IRSA)"
  value       = aws_iam_role.vpc_cni.arn
}

output "eks_secrets_kms_key_arn" {
  description = "KMS key ARN used for EKS etcd secret encryption"
  value       = aws_kms_key.eks_secrets.arn
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl after terraform apply"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${data.aws_region.current.name}"
}
