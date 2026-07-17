# SAML 2.0 client (active when client_protocol = "saml")

resource "keycloak_saml_client" "this" {
  count = local.is_saml ? 1 : 0

  realm_id                   = local.realm_id
  client_id                  = var.client_id
  name                       = local.client_name
  enabled                    = var.enabled
  consent_required           = var.consent_required
  login_theme                = var.login_theme
  root_url                   = var.root_url
  base_url                   = var.base_url
  full_scope_allowed         = var.full_scope_allowed
  valid_redirect_uris        = var.valid_redirect_uris
  idp_initiated_sso_url_name = var.idp_initiated_sso_url_name
  master_saml_processing_url = var.master_saml_processing_url
  sign_assertions            = var.sign_assertions
  sign_documents             = var.sign_documents
  force_name_id_format       = var.force_name_id_format
  force_post_binding         = var.force_post_binding
  name_id_format             = var.name_id_format
  encrypt_assertions         = var.encrypt_assertions
  include_authn_statement    = var.include_authn_statement
  signature_algorithm        = var.signature_algorithm
  signature_key_name         = var.signature_key_name
  canonicalization_method    = var.canonicalization_method
  front_channel_logout       = var.front_channel_logout

  signing_certificate = local.signing_certificate
  signing_private_key = local.signing_private_key

  client_signature_required           = var.encrypt_assertions
  assertion_consumer_post_url         = var.assertion_consumer_post_url
  logout_service_post_binding_url     = var.logout_service_post_binding_url
  logout_service_redirect_binding_url = var.logout_service_redirect_binding_url
}

# Remove the default 'role_list' client scope (duplicate Role attributes break some SAML SPs).
resource "keycloak_saml_client_default_scopes" "default_scopes" {
  count = local.is_saml ? 1 : 0

  realm_id  = local.realm_id
  client_id = keycloak_saml_client.this[0].id

  default_scopes = []
}
