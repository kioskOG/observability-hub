# TLS Resources for SAML Client Signing Certificate Generation
# Conditionally created when certificate_strategy is set to "generate"

resource "tls_private_key" "this" {
  count     = var.certificate_strategy == "generate" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  count           = var.certificate_strategy == "generate" ? 1 : 0
  private_key_pem = tls_private_key.this[0].private_key_pem

  subject {
    common_name  = var.client_id
    organization = "Internal IAM Platform"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
  ]
}
