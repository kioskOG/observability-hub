output "ecr_repository_urls" {
  description = "Map of repository name to ECR URL"
  value       = { for k, repo in aws_ecr_repository.repo_create : k => repo.repository_url }
}

output "ecr_repository_arns" {
  description = "Map of repository name to ECR ARN"
  value       = { for k, repo in aws_ecr_repository.repo_create : k => repo.arn }
}
