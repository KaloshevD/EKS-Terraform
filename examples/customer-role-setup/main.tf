# Runs by the CUSTOMER, in the CUSTOMER's account.
# terraform init && terraform apply
# Then send the `role_arn` output to your platform team, and share the
# external_id value out-of-band (not in chat, not in a ticket).

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Uses the customer's own credentials - whatever they normally use to
  # log into their own AWS account (SSO profile, IAM user, etc).
}

variable "aws_region" {
  description = "AWS region the customer operates in."
  type        = string
  default     = "eu-central-1"
}

variable "management_account_id" {
  description = "The platform's AWS account ID. Provided by the platform team."
  type        = string
}

variable "external_id" {
  description = "Unique secret for this customer, generated with: openssl rand -hex 16"
  type        = string
  sensitive   = true
}

module "provisioner_role" {
  source = "../../modules/customer-account-role"

  management_account_id = var.management_account_id
  external_id           = var.external_id
  role_name             = "PlatformProvisionerRole"

  tags = {
    ManagedBy = "terraform"
    Purpose   = "platform-eks-provisioning"
  }
}

output "role_arn" {
  description = "Send this to the platform team."
  value       = module.provisioner_role.role_arn
}
