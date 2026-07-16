resource "aws_iam_policy" "policy" {
  for_each = toset(var.iam_policy)
  name     = each.key
  path     = "/"
  policy   = templatefile("policy/${each.key}.json", var.policy_vars)
  tags     = var.additional_tags
}
