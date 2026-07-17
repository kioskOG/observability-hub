output "endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_iam_role_arn" {
  description = "Cluster IAM Role ARN"
  value       = aws_iam_role.cluster_role.arn
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.eks_cluster.id
}

output "eks_cluster_arn" {
  description = "EKS resource ARN"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "eks_security_group_id" {
  description = "SG ID"
  value       = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}


#### Node Group ####
output "node_groups_name" {
  description = "ARN of node group"
  value = {
    for node_group in aws_eks_node_group.node_groups :
    node_group.id => node_group.node_group_name
  }
}

output "node_iam_role_arn" {
  description = "Worker nodes IAM Role ARN"
  value       = aws_iam_role.node_group_role.*.arn
}

output "node_group_security_group_id" {
  value = aws_security_group.worker_sg.id
}


output "node_group_security_group_name" {
  value = aws_security_group.worker_sg.name
}


### Fargate ###

output "aws_eks_fargate_profile" {
  value = { for k, v in aws_eks_fargate_profile.fargate : k => v.id }
}

output "aws_iam_role" {
  value = aws_iam_role.fargate_role
}


#### KMS ####

output "aws_kms_key" {
  value = var.create_kms == true ? aws_kms_key.eks_cluster[0].arn : null
}

output "private_key" {
  value     = tls_private_key.default.private_key_pem
  sensitive = true
}

output "eks_access_entries" {
  value = { for k, v in aws_eks_access_entry.this : k => {
    principal_arn = v.principal_arn
    type          = v.type
  } }
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_issuer_url" {
  description = "The URL of the OIDC Issuer"
  value       = aws_iam_openid_connect_provider.cluster.url
}
