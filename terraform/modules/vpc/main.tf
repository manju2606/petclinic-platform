locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── VPC ──────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-vpc"
    Component = "networking"
  })
}

# ── Default Security Group — locked down ─────────────────────────────────────
# AWS creates a default SG for every VPC with allow-all rules. We adopt it and
# remove all rules so that resources accidentally provisioned without an explicit
# SG get deny-all behaviour instead of allow-all.

resource "aws_default_security_group" "lockdown" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-default-sg-locked"
    Component = "networking"
  })
}

# ── Internet Gateway ──────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-igw"
    Component = "networking"
  })
}

# ── Public Subnets ────────────────────────────────────────────────────────────
# All-public design (no NAT Gateway) — SGs are the access control perimeter.
# map_public_ip_on_launch is intentional: EKS nodes need internet-reachable IPs
# to pull from ECR and reach AWS APIs without a NAT Gateway (see ADR-0001).

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                         = "${local.name_prefix}-public-${count.index + 1}"
    Component                                    = "networking"
    "kubernetes.io/cluster/${local.name_prefix}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  })
}

# ── Route Table ───────────────────────────────────────────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-public-rt"
    Component = "networking"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── VPC Flow Logs ─────────────────────────────────────────────────────────────
# Detective control for the all-public design: flow logs are the only
# network-layer audit trail available when there are no private subnets.

resource "aws_cloudwatch_log_group" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${local.name_prefix}"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-flow-log-group"
    Component = "networking"
  })
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log_policy" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [
      aws_cloudwatch_log_group.flow_log[0].arn,
      "${aws_cloudwatch_log_group.flow_log[0].arn}:*",
    ]
  }
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${local.name_prefix}-vpc-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-vpc-flow-log-role"
    Component = "networking"
  })
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${local.name_prefix}-vpc-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log_policy[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log[0].arn
  log_destination = aws_cloudwatch_log_group.flow_log[0].arn

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-flow-log"
    Component = "networking"
  })
}

# ── Security Groups ───────────────────────────────────────────────────────────
# Rules managed via separate aws_security_group_rule resources (EKS, ALB) or
# inline blocks (RDS — uses egress=[] to explicitly block all outbound traffic).
# Mixing inline and separate resources on the same SG is not supported.

resource "aws_security_group" "eks_cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "EKS control plane - allows HTTPS from worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-eks-cluster-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "eks_node" {
  name        = "${local.name_prefix}-eks-node-sg"
  description = "EKS worker nodes - allows inter-node, control-plane, and ALB NodePort traffic"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-eks-node-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS uses inline rules so that egress = [] explicitly removes the AWS default
# allow-all outbound rule, leaving no outbound path from the database.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS MySQL - allows port 3306 from EKS nodes only, no outbound"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "MySQL from EKS nodes only"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = [aws_security_group.eks_node.id]
    self             = false
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
  }

  egress = []

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-rds-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Application Load Balancer - allows HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name      = "${local.name_prefix}-alb-sg"
    Component = "networking"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ── EKS Cluster SG Rules ──────────────────────────────────────────────────────

resource "aws_security_group_rule" "cluster_ingress_nodes_https" {
  security_group_id        = aws_security_group.eks_cluster.id
  type                     = "ingress"
  description              = "HTTPS from worker nodes to API server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "egress"
  description       = "Allow all outbound traffic from control plane"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── EKS Node SG Rules ─────────────────────────────────────────────────────────

resource "aws_security_group_rule" "node_ingress_cluster_all" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "All traffic from EKS control plane"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_self" {
  security_group_id = aws_security_group.eks_node.id
  type              = "ingress"
  description       = "Inter-node communication"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
}

resource "aws_security_group_rule" "node_ingress_kubelet" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "Kubelet API from cluster control plane"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "node_ingress_nodeport_alb" {
  security_group_id        = aws_security_group.eks_node.id
  type                     = "ingress"
  description              = "NodePort services from ALB"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "node_egress_all" {
  security_group_id = aws_security_group.eks_node.id
  type              = "egress"
  description       = "Allow all outbound traffic from worker nodes"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── ALB SG Rules ──────────────────────────────────────────────────────────────

resource "aws_security_group_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress_nodeport" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "NodePort traffic to EKS worker nodes"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}

resource "aws_security_group_rule" "alb_egress_health" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "Health check traffic to EKS worker nodes"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node.id
}
