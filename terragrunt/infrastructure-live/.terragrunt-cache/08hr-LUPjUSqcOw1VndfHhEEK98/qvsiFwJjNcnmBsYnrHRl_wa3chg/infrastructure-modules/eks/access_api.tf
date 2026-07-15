# data "aws_caller_identity" "this" {}

# # Give the TF caller (or your chosen admin role) cluster-admin via Access API
# resource "aws_eks_access_entry" "bootstrap_admin" {
#   cluster_name  = aws_eks_cluster.eks_cluster.name
#   principal_arn = data.aws_caller_identity.this.arn
#   type          = "STANDARD"
# }

# resource "aws_eks_access_policy_association" "bootstrap_admin" {
#   cluster_name  = aws_eks_cluster.eks_cluster.name
#   principal_arn = aws_eks_access_entry.bootstrap_admin.principal_arn
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   access_scope { type = "cluster" }
# }


# # Access entries (who)
# resource "aws_eks_access_entry" "this" {
#   for_each = {
#     for ae in var.access_entries : ae.principal_arn => ae
#   }

#   cluster_name  = aws_eks_cluster.eks_cluster.name
#   principal_arn = each.value.principal_arn
#   type          = each.value.type # STANDARD | EC2_LINUX
# }

# # Policy associations (what + scope)
# resource "aws_eks_access_policy_association" "this" {
#   for_each = aws_eks_access_entry.this

#   cluster_name  = aws_eks_cluster.eks_cluster.name
#   principal_arn = each.value.principal_arn
#   policy_arn    = local.access_policies[
#     lookup(
#       { for ae in var.access_entries : ae.principal_arn => ae.policy_key },
#       each.value.principal_arn,
#       "view" # fallback if not found
#     )
#   ]

#   dynamic "access_scope" {
#     for_each = [lookup({ for ae in var.access_entries : ae.principal_arn => ae }, each.value.principal_arn)]
#     content {
#       type       = access_scope.value.scope_type
#       namespaces = try(access_scope.value.namespaces, null)
#     }
#   }
# }


# access_api.tf

# Give the bootstrap principal cluster-admin via Access API
resource "aws_eks_access_entry" "bootstrap_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = var.bootstrap_admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bootstrap_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = var.bootstrap_admin_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

# Access entries (who)
resource "aws_eks_access_entry" "this" {
  for_each = {
    for ae in var.access_entries : ae.principal_arn => ae
  }

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = each.value.principal_arn
  type          = each.value.type # STANDARD | EC2_LINUX
}

# Policy associations (what + scope)
resource "aws_eks_access_policy_association" "this" {
  for_each = {
    for ae in var.access_entries : ae.principal_arn => ae
    if ae.type == "STANDARD"
  }

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = each.value.principal_arn

  policy_arn = local.access_policies[
    lookup(
      { for ae in var.access_entries : ae.principal_arn => ae.policy_key },
      each.value.principal_arn,
      "view"
    )
  ]

  access_scope {
    type       = lookup({ for ae in var.access_entries : ae.principal_arn => ae.scope_type }, each.value.principal_arn, "cluster")
    namespaces = try(lookup({ for ae in var.access_entries : ae.principal_arn => ae.namespaces }, each.value.principal_arn, null), null)
  }
}
