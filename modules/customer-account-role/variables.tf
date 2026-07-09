variable "management_account_id" {
  description = "AWS account ID of the management (provider) account that will assume this role."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be a 12-digit AWS account ID."
  }
}

variable "external_id" {
  description = <<-EOT
    A shared secret required in the AssumeRole call, to protect against the
    "confused deputy" problem (where a third party tricks the management
    account into assuming a role it wasn't meant to assume on the customer's
    behalf). Generate a unique, random value per customer - do not reuse
    across accounts. Treat it as a secret; store it in your secrets manager,
    not in version control.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.external_id) >= 20
    error_message = "external_id should be at least 20 characters. Generate with: openssl rand -hex 16"
  }
}

variable "role_name" {
  description = "Name of the IAM role created in the customer account."
  type        = string
  default     = "PlatformProvisionerRole"
}

variable "permissions_boundary_arn" {
  description = "Optional IAM permissions boundary ARN to attach to the role, capping its maximum possible privileges regardless of the attached policy."
  type        = string
  default     = null
}

variable "session_duration_seconds" {
  description = "Maximum session duration for assumed-role sessions (900-43200 seconds)."
  type        = number
  default     = 3600

  validation {
    condition     = var.session_duration_seconds >= 900 && var.session_duration_seconds <= 43200
    error_message = "session_duration_seconds must be between 900 and 43200."
  }
}

variable "require_mfa" {
  description = "If true, require the calling principal's session to have been established with MFA (only meaningful if the management account principal is a user, not a role - most cross-account automation uses roles, so this typically stays false and relies on external_id instead)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}
