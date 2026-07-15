# Realm Management
resource "keycloak_realm" "this" {
  count                          = var.create_realm ? 1 : 0
  realm                          = var.realm_name
  enabled                        = true
  display_name                   = var.realm_display_name
  display_name_html              = var.realm_display_name_html
  login_theme                    = var.realm_login_theme
  account_theme                  = var.realm_account_theme
  admin_theme                    = var.realm_admin_theme
  email_theme                    = var.realm_email_theme
  ssl_required                   = var.ssl_required
  remember_me                    = var.remember_me
  registration_allowed           = var.registration_allowed
  registration_email_as_username = var.registration_email_as_username
  edit_username_allowed          = var.edit_username_allowed
  reset_password_allowed         = var.reset_password_allowed
  verify_email                   = var.verify_email
  login_with_email_allowed       = var.login_with_email_allowed
  duplicate_emails_allowed       = var.duplicate_emails_allowed
  attributes                     = var.realm_attributes
  password_policy                = local.password_policy_string

  dynamic "smtp_server" {
    for_each = local.smtp_config != null ? [local.smtp_config] : []
    content {
      host              = smtp_server.value.host
      port              = smtp_server.value.port
      from              = smtp_server.value.from
      from_display_name = smtp_server.value.from_display_name
      reply_to          = smtp_server.value.reply_to
      ssl               = smtp_server.value.ssl
      starttls          = smtp_server.value.starttls

      dynamic "auth" {
        for_each = smtp_server.value.username != null ? [1] : []
        content {
          username = smtp_server.value.username
          password = local.resolved_smtp_password
        }
      }
    }
  }

  dynamic "otp_policy" {
    for_each = try(var.mfa.enabled, false) && contains(try(var.mfa.methods, []), "totp") ? [1] : []
    content {
      type      = "totp"
      algorithm = "HmacSHA1"
      digits    = 6
    }
  }
}

data "keycloak_realm" "this" {
  count = var.create_realm ? 0 : 1
  realm = var.realm_name
}

# SAML Client Configuration
resource "keycloak_saml_client" "this" {
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

  # Optional client signature requirements if encrypting or required
  client_signature_required           = var.encrypt_assertions
  assertion_consumer_post_url         = var.assertion_consumer_post_url
  logout_service_post_binding_url     = var.logout_service_post_binding_url
  logout_service_redirect_binding_url = var.logout_service_redirect_binding_url
}

# Remove the default 'role_list' client scope because it generates duplicate
# SAML attributes (Single Role Attribute = false) which breaks OpenSearch java-saml parsing.
# We use custom mappers instead.
resource "keycloak_saml_client_default_scopes" "default_scopes" {
  realm_id  = local.realm_id
  client_id = keycloak_saml_client.this.id

  default_scopes = []
}
