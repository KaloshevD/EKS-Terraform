# Architecture

## Trust model

![Cross-account trust diagram](docs/diagrams/cross-account-trust.svg)

The core object in this repo is a single IAM trust relationship. In the customer's account,
`modules/customer-account-role` creates:

```hcl
principals {
  type        = "AWS"
  identifiers = ["arn:aws:iam::<management_account_id>:root"]
}

condition {
  test     = "StringEquals"
  variable = "sts:ExternalId"
  values   = [var.external_id]
}
```

Two things matter here:

1. **The principal is the management account root**, not a specific IAM user or role in that
   account. This means the *management account* decides internally which of its own roles/users
   are allowed to call `sts:AssumeRole` against this ARN (via that principal's own IAM policy) -
   the customer isn't trying to track your internal IAM structure, and you can rotate which of
   your internal roles does the assuming without ever touching the customer's Terraform.
2. **The external ID is the actual access control.** Knowing the management account's ID is not
   secret - it's often public. Without the external ID condition, any process in the management
   account with `sts:AssumeRole` permissions could call this role. The external ID is the piece
   that has to be deliberately handed to the platform out-of-band, and it's what lets the
   customer revoke access unilaterally by rotating it - deleting the role achieves the same
   thing but is more disruptive to reverse if it was accidental.

This is the textbook mitigation for the **confused deputy problem**: without an external ID, a
malicious third party who convinces your automation to assume a role using their supplied ARN
could trick your systems (the "deputy," which has more privilege than the third party) into
acting on their behalf. Docs: [AWS - the confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html).

## Sequence of operations

1. Customer runs `examples/customer-role-setup` (wraps `modules/customer-account-role`) using
   their own credentials. Nothing about this step requires them to trust the platform with
   anything beyond the future `AssumeRole` call - they can read the entire policy before
   applying.
2. Customer hands the platform two things, through two different, ideally out-of-band channels:
   the `role_arn` output (not sensitive, safe to send in a ticket) and the `external_id` (treat
   as a secret - a password manager share, not Slack).
3. Platform's Terraform provider block (`examples/full-deployment/providers.tf`) configures an
   `aws.customer` provider alias with an `assume_role { role_arn, external_id }` block. Every
   resource declared with `providers = { aws = aws.customer }` is created using temporary STS
   credentials scoped to that role - typically valid for up to the role's configured
   `max_session_duration` (default here: 1 hour).
4. `modules/eks-cluster`, invoked with that provider, creates a VPC
   (`terraform-aws-modules/vpc/aws`) and an EKS cluster (`terraform-aws-modules/eks/aws`) with
   managed node groups, inside the customer's account, using only the permissions granted in
   step 1's policy document.
5. The EKS module also stands up an IAM OIDC provider tied to the cluster's issuer URL. This is
   what unlocks IRSA (IAM Roles for Service Accounts) - a specific Kubernetes ServiceAccount, not
   the whole node, can assume a specific IAM role. This is the mechanism a downstream project
   (a custom operator) depends on to reach AWS Secrets Manager or ECR without broadening the
   node instance profile's permissions.

## Failure modes considered

- **External ID leaks.** Mitigation: it's `sensitive = true` in Terraform (won't print in
  `plan`/`apply` output or state UI), and the README explicitly calls out not committing it to
  version control or plaintext tickets. If it does leak, the customer rotates it by re-applying
  `modules/customer-account-role` with a new value - the old external ID immediately stops
  working, no coordination with the platform required.
- **AssumeRole call succeeds but with insufficient permissions.** The scoped policy document in
  `customer-account-role/main.tf` is deliberately narrow. If `terraform apply` in
  `eks-cluster` fails on a missing permission, that's treated as a signal to *add the specific
  action* to the policy document (and re-review it), not to fall back to a broad managed policy.
- **Assumed session expires mid-apply.** `max_session_duration` is configurable
  (`session_duration_seconds`, default 3600s). Long-running applies (initial cluster creation
  can take 10-15 minutes) are within a single assumed session as long as the AWS provider
  refreshes correctly; for very large changesets this is a reason to raise the max session
  duration on the customer side rather than re-authenticate mid-apply.
- **Customer deletes the role while platform Terraform state still references resources
  in their account.** Terraform state stored by the platform will become unreadable/unmanageable
  for that customer until the role is recreated. This is an accepted trade-off - the customer's
  ability to unilaterally revoke access is the point - but it means state per customer should be
  isolated (separate state file/workspace per customer) so one revocation doesn't block
  operations on other customers' infrastructure.
- **IAM eventual consistency.** Newly created IAM roles/policies can take a few seconds to
  propagate before they're usable in an `AssumeRole` call. Not explicitly handled with retries
  in this repo (Terraform's AWS provider has some built-in retry/backoff for this), but worth
  calling out for anyone extending this into a fully automated onboarding pipeline.

## Why not a managed policy like PowerUserAccess?

It would work, and it would be less code. It also means a customer's security team either has to
trust "PowerUserAccess minus IAM" blindly, or diff a very long AWS-managed policy against their
own risk tolerance every time it changes upstream. A short, explicit policy document that lives
in this repo's git history is auditable, diffable in pull requests, and makes "what exactly can
this platform do in our account" a two-minute read instead of a research project. That's worth
more than the maintenance overhead of occasionally adding an action when a new AWS feature is
adopted.
