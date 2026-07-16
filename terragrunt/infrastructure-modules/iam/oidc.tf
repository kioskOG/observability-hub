data "tls_certificate" "this" {
  for_each = var.oidc
  url      = each.value.tls_certificate_url != "" ? each.value.tls_certificate_url : each.value.url
}

resource "aws_iam_openid_connect_provider" "oidc" {
  for_each        = var.oidc
  client_id_list  = each.value.client_id_list
  thumbprint_list = concat([data.tls_certificate.this[each.key].certificates.0.sha1_fingerprint], each.value.custom_oidc_thumbprints)
  url             = each.value.url

  tags = var.additional_tags
}