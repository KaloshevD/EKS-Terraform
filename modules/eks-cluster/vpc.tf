#
# VPC for the cluster. Runs against whichever provider was passed to this
# module by the caller - in the cross-account flow, that provider is
# configured with an assume_role block pointing at the customer's
# PlatformProvisionerRole (see examples/full-deployment/providers.tf).
#

locals {
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, var.private_subnet_newbits, i)]
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, var.public_subnet_newbits, i + 48)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for the AWS Load Balancer Controller and cluster-autoscaler
  # to auto-discover subnets.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  }

  tags = var.tags
}
