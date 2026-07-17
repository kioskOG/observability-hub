output "iam_roles" {
  description = "List of all IAM Roles"
  value = [
    for role in aws_iam_role.default : role.arn
  ]
}

output "iam_role_arns" {
  description = "Map of all IAM Roles ARNs by name"
  value = {
    for k, role in aws_iam_role.default : k => role.arn
  }
}

output "iam_policy" {
  description = "List of all IAM Polcies"
  value = [
    for policy in aws_iam_policy.policy : policy.arn
  ]
}

output "oidc" {
  description = "List of all OIDC Providers"
  value = [
    for oidc in aws_iam_openid_connect_provider.oidc : oidc.arn
  ]
}
