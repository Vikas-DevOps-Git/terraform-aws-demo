locals {
  common_tags = {
    Environment   = var.environment
    ManagedBy     = "terraform"
    ComplianceTag = "sox-compliant"
  }
}

resource "aws_eks_cluster" "main" {
  name     = "${var.environment}-eks-cluster"
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider { key_arn = var.kms_key_arn }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  tags = merge(local.common_tags, { Name = "${var.environment}-eks" })
}

resource "aws_security_group" "cluster" {
  name        = "${var.environment}-eks-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.environment}-eks-cluster-sg" })
}

# On-demand node group — core workloads
resource "aws_eks_node_group" "on_demand" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.environment}-on-demand"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.on_demand_instance_types
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.on_demand_desired
    min_size     = var.on_demand_min
    max_size     = var.on_demand_max
  }

  labels = { role = "core", capacity = "on-demand" }
  tags   = merge(local.common_tags, { Name = "${var.environment}-on-demand-ng" })
}

# Spot node group — burst workloads
resource "aws_eks_node_group" "spot" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.environment}-spot"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.spot_instance_types
  capacity_type   = "SPOT"

  scaling_config {
    desired_size = var.spot_desired
    min_size     = var.spot_min
    max_size     = var.spot_max
  }

  labels = { role = "spot", capacity = "spot" }
  tags   = merge(local.common_tags, { Name = "${var.environment}-spot-ng" })
}

# OIDC provider for pod identity (Vault, ALB controller)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = local.common_tags
}
