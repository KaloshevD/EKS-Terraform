module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # OIDC provider for IRSA - IAM Roles for Service Accounts. This is what
  # lets Project 3's operator, or the AWS Load Balancer Controller, or
  # external-secrets, assume a scoped IAM role from inside a pod instead of
  # relying on broad node-instance-profile permissions.
  enable_irsa = var.enable_irsa

  cluster_enabled_log_types = var.cluster_log_types

  # Encrypt Kubernetes secrets at rest with a dedicated KMS key.
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  eks_managed_node_groups = {
    for name, ng in var.node_groups : name => {
      instance_types = ng.instance_types
      capacity_type  = ng.capacity_type
      min_size       = ng.min_size
      max_size       = ng.max_size
      desired_size   = ng.desired_size
      disk_size      = ng.disk_size
      labels         = ng.labels
      taints = {
        for idx, t in ng.taints : "taint-${idx}" => {
          key    = t.key
          value  = t.value
          effect = t.effect
        }
      }
      tags = var.tags
    }
  }

  fargate_profiles = var.enable_fargate ? {
    for name, profile in var.fargate_profiles : name => {
      selectors = profile.selectors
      tags      = var.tags
    }
  } : {}

  # Map the platform's IAM role into the aws-auth ConfigMap so ongoing
  # cluster operations (Helm installs, operator deploys) can authenticate
  # via kubectl without the customer having to hand-edit anything.
  access_entries = {
    platform_admin = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}
