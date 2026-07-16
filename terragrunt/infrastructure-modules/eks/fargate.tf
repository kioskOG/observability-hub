resource "aws_eks_fargate_profile" "fargate" {
  for_each               = var.fargate_profiles
  cluster_name           = aws_eks_cluster.eks_cluster.name
  fargate_profile_name   = substr(each.key, 0, 12)
  pod_execution_role_arn = aws_iam_role.fargate_role[0].arn
  subnet_ids             = each.value.subnets
  depends_on = [
    aws_eks_cluster.eks_cluster
  ]

  selector {
    namespace = each.value.namespace
    labels    = each.value.labels
  }

  tags = merge(
    {
      Name = format("%s-FargateProfile", substr(each.key, 0, 12))
    },
    {
      "Provisioner" = "Terraform"
    },
    each.value.tags
  )
}

resource "aws_iam_role" "fargate_role" {
  count = var.create_fargate_role ? 1 : 0
  name  = "${var.cluster_name}-fargate-profileRole"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:eks:${var.region}:${var.account_id}:fargateprofile/${var.cluster_name}/*"
        }
      }
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  count      = var.create_fargate_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_role[0].name
}
