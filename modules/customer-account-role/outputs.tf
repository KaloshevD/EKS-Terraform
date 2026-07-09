output "role_arn" {
  description = "ARN of the IAM role the management account should assume. Hand this (and the external_id, out of band) to the platform provider."
  value       = aws_iam_role.provisioner.arn
}

output "role_name" {
  description = "Name of the created IAM role."
  value       = aws_iam_role.provisioner.name
}
