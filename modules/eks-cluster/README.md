# eks-cluster

Run **by the platform (management account)**, against a provider configured to assume the
customer's `PlatformProvisionerRole`. Provisions a VPC and an EKS cluster with managed node
groups and/or Fargate profiles inside the customer's account.

This module does **not** configure the assume-role provider itself - that's the caller's
responsibility, so the same module can be reused for direct (single-account) deployments too.
See `examples/full-deployment/providers.tf` for the cross-account pattern.

## Usage

```hcl
module "eks" {
  source = "github.com/KaloshevD/eks-cross-account-terraform//modules/eks-cluster"

  providers = {
    aws = aws.customer
  }

  cluster_name    = "acme-corp-prod"
  cluster_version = "1.30"
  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 8
      desired_size   = 3
    }
    spot_batch = {
      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"
      min_size       = 0
      max_size       = 10
      desired_size   = 0
      taints = [{
        key    = "workload"
        value  = "batch"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Customer    = "acme-corp"
    Environment = "production"
  }
}
```

## Why `enable_irsa`?

IRSA (IAM Roles for Service Accounts) lets a specific Kubernetes service account assume a
specific IAM role, instead of every pod on a node inheriting the node's IAM permissions. This
module enables it by default and exposes `oidc_provider_arn` / `oidc_provider_url` as outputs
because Project 3 (a custom operator) needs them to build its own scoped IAM trust policy - the
operator's pod should be able to call AWS Secrets Manager or ECR without the underlying EC2
instance profile needing those permissions too.

## Inputs / Outputs

See `variables.tf` and `outputs.tf` - both are documented inline. The short version: everything
about cluster size, node group shape, and Fargate is configurable; `oidc_provider_arn`,
`cluster_name`, and `vpc_id` are the outputs downstream projects (Helm charts, the operator)
will need.
