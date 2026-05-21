variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "petclinic"
}

variable "cluster_admin_arns" {
  description = "IAM principal ARNs to grant EKS cluster admin access. Add your IAM user/role ARN here to enable kubectl after deploy. Example: [\"arn:aws:iam::123456789012:role/your-deploy-role\"]"
  type        = list(string)
  default     = []
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Override with your DevOps team egress CIDRs to restrict prod API access (e.g., office IP, CI/CD runner IP)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_capacity_type" {
  description = "EC2 capacity type for the managed node group. Keep ON_DEMAND for prod stability."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}
