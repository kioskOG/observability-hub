resource "aws_iam_role" "default" {
  for_each           = var.iam_role
  name               = each.key
  path               = "/"
  assume_role_policy = file("trusted-entity/${each.key}.json")
  tags               = var.additional_tags
}

resource "aws_iam_role_policy" "default" {
  for_each = toset(local.local_iam_role_custom_policy)
  name     = split("@", each.key)[1]
  role     = aws_iam_role.default[split("@", each.key)[0]].id
  policy   = file("policy/${split("@", each.key)[1]}.json")
}

resource "aws_iam_role_policy_attachment" "managed" {
  depends_on = [
    aws_iam_role.default
  ]
  for_each   = toset(local.local_iam_role_managed_policy)
  role       = aws_iam_role.default[split("@", each.key)[0]].name
  policy_arn = "arn:aws:iam::aws:policy/${split("@", each.key)[1]}"
}


resource "aws_iam_instance_profile" "default" {
  for_each = toset(local.local_iam_instance_profile)
  name     = each.key
  role     = each.key
}