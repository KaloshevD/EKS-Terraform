#
# This module is applied INSIDE THE CUSTOMER'S AWS ACCOUNT.
#
# It creates a single IAM role that trusts the management account, and only
# the management account. The trust is further scoped with an external ID
# condition, so possession of the management account's credentials alone is
# not enough to assume this role - the caller also needs to know the
# customer-specific external ID.
#
# No credentials for the customer account are ever shared with the
# management account. The customer retains full control: they can revoke
# access at any time by deleting this role or rotating the external ID.
#

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowManagementAccountAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.management_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role" "provisioner" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.session_duration_seconds
  permissions_boundary = var.permissions_boundary_arn
  description          = "Assumed by the management account to provision EKS infrastructure in this account. Created by eks-cross-account-terraform/modules/customer-account-role."

  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Purpose   = "cross-account-eks-provisioning"
  })
}

# Scoped policy: only what's needed to stand up a VPC + EKS cluster +
# managed node groups + IRSA/OIDC. Deliberately NOT AdministratorAccess or
# PowerUserAccess - a customer reviewing this in a security audit should be
# able to read exactly what they've granted.
data "aws_iam_policy_document" "provisioner_permissions" {
  statement {
    sid    = "EKSFullAccess"
    effect = "Allow"
    actions = [
      "eks:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VPCAndNetworking"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs", "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
      "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags",
      "ec2:DescribeAvailabilityZones", "ec2:DescribeAccountAttributes",
      "ec2:RunInstances", "ec2:TerminateInstances", "ec2:DescribeInstances",
      "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMForClusterAndNodeRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:PassRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy",
      "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies", "iam:TagRole", "iam:UntagRole",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:GetInstanceProfile",
    ]
    # Scoped to roles this platform creates, identifiable by name prefix.
    # Tighten this further to your naming convention in production.
    resources = [
      "arn:aws:iam::*:role/eks-*",
      "arn:aws:iam::*:instance-profile/eks-*",
      "arn:aws:iam::*:oidc-provider/*",
    ]
  }

  statement {
    sid       = "KMSForSecretEncryption"
    effect    = "Allow"
    actions   = ["kms:CreateKey", "kms:DescribeKey", "kms:CreateAlias", "kms:DeleteAlias", "kms:ScheduleKeyDeletion", "kms:TagResource"]
    resources = ["*"]
  }

  statement {
    sid       = "CloudWatchLogsForControlPlaneLogging"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups", "logs:PutRetentionPolicy", "logs:TagResource"]
    resources = ["arn:aws:logs:*:*:log-group:/aws/eks/*"]
  }
}

resource "aws_iam_role_policy" "provisioner_permissions" {
  name   = "${var.role_name}-eks-provisioning"
  role   = aws_iam_role.provisioner.id
  policy = data.aws_iam_policy_document.provisioner_permissions.json
}
