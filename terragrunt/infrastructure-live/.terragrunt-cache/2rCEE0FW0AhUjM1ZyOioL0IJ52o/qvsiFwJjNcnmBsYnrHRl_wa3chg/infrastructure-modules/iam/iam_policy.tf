resource "aws_iam_policy" "policy" {
  for_each = toset(var.iam_policy)
  name     = each.key
  path     = "/"
  policy   = file("policy/${each.key}.json")
  tags     = var.additional_tags
}
