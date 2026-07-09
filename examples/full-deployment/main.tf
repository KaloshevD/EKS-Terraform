variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "customer_role_arn" {
  description = "The role_arn output the customer sent you after running examples/customer-role-setup."
  type        = string
}

variable "external_id" {
  description = "The external ID you generated for this customer and shared out-of-band."
  type        = string
  sensitive   = true
}

variable "customer_name" {
  description = "Short identifier for this customer, used in resource naming/tagging."
  type        = string
}

module "eks" {
  source = "../../modules/eks-cluster"

  providers = {
    aws = aws.customer
  }

  cluster_name    = "${var.customer_name}-eks"
  cluster_version = "1.30"
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 6
      desired_size   = 2
    }
  }

  enable_irsa = true

  tags = {
    Customer  = var.customer_name
    ManagedBy = "terraform"
  }
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "Needed for Project 3's operator IAM role trust policy."
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --role-arn ${var.customer_role_arn}"
}
