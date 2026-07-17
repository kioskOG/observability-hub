# Realm only — protocol clients live in saml.tf / oidc.tf

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
