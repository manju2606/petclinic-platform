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

variable "authentication_mode" {
  description = "EKS cluster authentication mode. API_AND_CONFIG_MAP supports both access entries and legacy aws-auth ConfigMap. Migrate to API to eliminate the ConfigMap attack surface once all access is via access entries."
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["API", "CONFIG_MAP", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be API, CONFIG_MAP, or API_AND_CONFIG_MAP."
  }
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether the cluster creator IAM principal automatically gets cluster-admin access. Set to false and supply cluster_admin_arns so all admin access is explicit and auditable (recommended for new clusters)."
  type        = bool
  default     = true
}

variable "node_capacity_type" {
  description = "EC2 capacity type for the managed node group: ON_DEMAND or SPOT. ON_DEMAND during the Graviton free trial; switch to SPOT in dev for cost savings after the trial expires."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "addon_resolve_conflicts_on_update" {
  description = "Conflict resolution when updating EKS managed add-ons. OVERWRITE discards manual config changes (fine for dev). PRESERVE fails on conflict so manual hotfixes are not silently reverted (recommended for prod)."
  type        = string
  default     = "OVERWRITE"

  validation {
    condition     = contains(["OVERWRITE", "PRESERVE", "NONE"], var.addon_resolve_conflicts_on_update)
    error_message = "addon_resolve_conflicts_on_update must be OVERWRITE, PRESERVE, or NONE."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
