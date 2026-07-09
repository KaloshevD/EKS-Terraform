output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane."
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA. Used by Project 3's operator to build a service-account-scoped IAM role trust policy."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider, without the https:// prefix - as required in IAM trust policy conditions."
  value       = module.eks.oidc_provider
}

output "vpc_id" {
  description = "ID of the VPC created for this cluster."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (where nodes run)."
  value       = module.vpc.private_subnets
}

output "configure_kubectl" {
  description = "Command to update local kubeconfig for this cluster. Requires assuming the same customer role first."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region <region> --role-arn <customer-role-arn>"
}
