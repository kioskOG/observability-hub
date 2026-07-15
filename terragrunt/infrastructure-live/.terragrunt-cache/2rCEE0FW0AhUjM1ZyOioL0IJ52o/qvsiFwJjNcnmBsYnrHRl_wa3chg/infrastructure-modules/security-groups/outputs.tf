output "security_group_ids" {
  description = "Security group IDs"
  value       = { for k, sg in aws_security_group.this : k => sg.id }
}

output "security_group_arns" {
  description = "Security group ARNs"
  value       = { for k, sg in aws_security_group.this : k => sg.arn }
}
