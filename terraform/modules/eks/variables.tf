variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod'."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS cluster control plane and node group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for multi-AZ EKS."
  }
}

variable "cluster_sg_id" {
  description = "EKS cluster (control plane) security group ID"
  type        = string
}

variable "node_sg_id" {
  description = "EKS node security group ID — attached to nodes via launch template"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t4g.small"]
}

variable "node_ami_type" {
  description = "AMI type for nodes. AL2023_ARM_64_STANDARD for Graviton t4g (Amazon Linux 2023, supported through 2028). AL2_ARM_64 reached EOL June 2025."
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired number of nodes at creation (Terraform ignores drift after initial deploy)"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Root EBS volume size in GB for each node (gp3, encrypted)"
  type        = number
  default     = 20
}

variable "cluster_public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Defaults to unrestricted. Override with your team's known egress CIDRs in production (e.g., [\"203.0.113.10/32\"])."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_admin_arns" {
  description = "IAM principal ARNs granted AmazonEKSClusterAdminPolicy via EKS access entries. Add the ARN of the IAM user/role that runs terraform apply so that kubectl works after deployment."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
