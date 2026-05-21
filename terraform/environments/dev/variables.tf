variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "petclinic"
}

variable "cluster_admin_arns" {
  description = "IAM principal ARNs to grant EKS cluster admin access. Add your IAM user/role ARN here to enable kubectl after deploy. Example: [\"arn:aws:iam::123456789012:user/myuser\"]"
  type        = list(string)
  default     = []
}
