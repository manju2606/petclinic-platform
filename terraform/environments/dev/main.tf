locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "vpc" {
  source = "../../modules/vpc"

  project             = var.project
  environment         = var.environment
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones  = ["${var.aws_region}a", "${var.aws_region}b"]
}

module "eks" {
  source = "../../modules/eks"

  project             = var.project
  environment         = var.environment
  cluster_version     = "1.29"
  subnet_ids          = module.vpc.public_subnet_ids
  cluster_sg_id       = module.vpc.eks_cluster_sg_id
  node_sg_id          = module.vpc.eks_node_sg_id
  node_instance_types         = ["t4g.small"]
  node_ami_type               = "AL2023_ARM_64_STANDARD"
  node_capacity_type          = var.node_capacity_type
  node_min_size               = 2
  node_max_size               = 4
  node_desired_size           = 2
  node_disk_size              = 20
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  cluster_admin_arns          = var.cluster_admin_arns
}
