resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = each.key
  description = each.value.description
  kms_key_id  = each.value.kms_key_id
  tags        = each.value.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode(each.value.values)
}
