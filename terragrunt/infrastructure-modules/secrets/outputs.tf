output "secret_arns" {
  description = "ARNs of the created secrets"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
