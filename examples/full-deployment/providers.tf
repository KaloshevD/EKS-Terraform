# Runs by THE PLATFORM (management account).
#
# The `aws.customer` provider alias below is the entire trick: every
# resource that uses `providers = { aws = aws.customer }` gets created
# inside the customer's account, using temporary credentials obtained by
# assuming their PlatformProvisionerRole - never the customer's long-lived
# credentials, never a shared static key.

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60"
    }
  }
}

# Default provider: the management account itself. Used for anything the
# platform needs to track in its own account (e.g. a Terraform state
# backend, a Route53 zone for cluster DNS, a central logging bucket).
provider "aws" {
  region = var.aws_region
}

# Customer provider: assumes into the customer's account via the role they
# created with modules/customer-account-role. This is the only place the
# external_id is used - it never appears inside the customer's own account.
provider "aws" {
  alias  = "customer"
  region = var.aws_region

  assume_role {
    role_arn     = var.customer_role_arn
    external_id  = var.external_id
    session_name = "eks-platform-provisioning"
  }
}
