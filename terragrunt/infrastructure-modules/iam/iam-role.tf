data "aws_iam_policy_document" "irsa_trust" {
  for_each = {
    for k, v in var.iam_role : k => v
    if lookup(v, "irsa_service_accounts", null) != null
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"
      values   = [for sa in each.value.irsa_service_accounts : "system:serviceaccount:${sa}"]
    }
  }
}

resource "aws_iam_role" "default" {
  for_each           = var.iam_role
  name               = each.key
  path               = "/"
  assume_role_policy = lookup(each.value, "irsa_service_accounts", null) != null ? data.aws_iam_policy_document.irsa_trust[each.key].json : file("trusted-entity/${each.key}.json")
  tags               = var.additional_tags
}

resource "aws_iam_role_policy" "default" {
  for_each = toset(local.local_iam_role_custom_policy)
  name     = split("@", each.key)[1]
  role     = aws_iam_role.default[split("@", each.key)[0]].id
  policy   = templatefile("policy/${split("@", each.key)[1]}.json", var.policy_vars)
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