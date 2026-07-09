# customer-account-role

Run **by the customer, in the customer's own AWS account.** Creates a single, narrowly-scoped
IAM role that trusts your management account to assume it - and nothing else.

The customer keeps full ownership: no credentials leave their account, the role can be deleted
or the external ID rotated at any time to instantly revoke access, and every permission granted
is readable in `main.tf` rather than hidden behind `AdministratorAccess`.

## Usage

```hcl
module "provisioner_role" {
  source = "github.com/KaloshevD/eks-cross-account-terraform//modules/customer-account-role"

  management_account_id = "111111111111"   # your platform's AWS account ID
  external_id            = var.external_id  # generate with: openssl rand -hex 16
  role_name               = "PlatformProvisionerRole"

  tags = {
    Customer   = "acme-corp"
    CostCenter = "platform-eng"
  }
}

output "role_arn_for_platform" {
  value = module.provisioner_role.role_arn
}
```

After applying, send the customer the `role_arn` output and communicate the `external_id`
out-of-band (e.g. a password manager share, not Slack) - never commit it to source control.

## Inputs

| Name | Description | Default |
|---|---|---|
| `management_account_id` | Your platform's AWS account ID | *required* |
| `external_id` | Shared secret preventing confused-deputy attacks | *required* |
| `role_name` | Name of the created role | `PlatformProvisionerRole` |
| `permissions_boundary_arn` | Optional IAM permissions boundary | `null` |
| `session_duration_seconds` | Max assumed-role session length | `3600` |
| `require_mfa` | Require MFA on the assuming principal's session | `false` |

## Outputs

| Name | Description |
|---|---|
| `role_arn` | ARN to hand to the platform provider |
| `role_name` | Name of the created role |

## What permissions does this actually grant?

Only what's needed to create a VPC, an EKS cluster, managed node groups, an OIDC provider for
IRSA, and the supporting IAM roles/KMS keys/log groups - all scoped to resources with an
`eks-*` naming prefix where AWS's IAM model allows resource-level scoping. It is **not**
`AdministratorAccess` or `PowerUserAccess`. See `main.tf` for the literal policy document.
