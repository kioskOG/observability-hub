resource "aws_eks_addon" "this" {
  for_each      = { for k, v in var.cluster_addons : k => v }
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = try(each.value.name, each.key)
  addon_version = lookup(each.value, "addon_version", null) // "null" is the default version value if not passed as input
  # resolve_conflicts        = lookup(each.value, "resolve_conflicts", null)
  resolve_conflicts_on_update = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn    = lookup(each.value, "service_account_role_arn", null)
  configuration_values        = jsonencode(lookup(each.value, "configuration_values", {}))

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.node_groups
  ]

  tags = var.tags
}
