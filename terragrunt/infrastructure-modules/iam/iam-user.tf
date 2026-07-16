
resource "aws_iam_user" "default" {
  for_each = var.iam_user
  name     = each.key
  path     = "/"

  tags = merge(var.additional_tags, {
    Managed-Via = "Terraform"
  })
}

resource "aws_iam_group" "default" {
  for_each = var.iam_user
  name     = each.key
  path     = "/"
}

resource "aws_iam_group_membership" "default" {
  for_each = var.iam_user
  name     = each.key
  users    = [aws_iam_user.default[each.key].name]

  group = aws_iam_group.default[each.key].name
}


resource "aws_iam_group_policy" "default" {
  for_each = toset(local.local_iam_user_custom_policy)
  name     = split("@", each.key)[1]
  group    = aws_iam_user.default[split("@", each.key)[0]].name
  policy   = templatefile("policy/${split("@", each.key)[1]}.json", var.policy_vars)
}

resource "aws_iam_group_policy_attachment" "managed" {
  for_each = toset(local.local_iam_user_managed_policy)

  depends_on = [
    aws_iam_group.default
  ]
  group      = aws_iam_group.default[split("@", each.key)[0]].name
  policy_arn = "arn:aws:iam::aws:policy/${split("@", each.key)[1]}"
}
