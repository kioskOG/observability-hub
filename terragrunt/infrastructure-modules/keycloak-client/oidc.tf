# OpenID Connect client (active when client_protocol = "openid-connect")
# Application-specific claim/role mapping belongs in Terragrunt inputs (oidc_mappers, roles, groups).

resource "keycloak_openid_client" "this" {
  count = local.is_oidc ? 1 : 0

  realm_id                        = local.realm_id
  client_id                       = var.client_id
  name                            = local.client_name
  enabled                         = var.enabled
  description                     = var.client_description
  access_type                     = var.access_type
  standard_flow_enabled           = var.standard_flow_enabled
  implicit_flow_enabled           = var.implicit_flow_enabled
  direct_access_grants_enabled    = var.direct_access_grants_enabled
  service_accounts_enabled        = var.service_accounts_enabled
  valid_redirect_uris             = var.valid_redirect_uris
  valid_post_logout_redirect_uris = length(var.valid_post_logout_redirect_uris) > 0 ? var.valid_post_logout_redirect_uris : null
  web_origins                     = var.web_origins
  root_url                        = var.root_url != "" ? var.root_url : null
  base_url                        = var.base_url != "" ? var.base_url : null
  admin_url                       = var.admin_url != "" ? var.admin_url : null
  login_theme                     = var.login_theme != "" ? var.login_theme : null
  consent_required                = var.consent_required
  full_scope_allowed              = var.full_scope_allowed
  pkce_code_challenge_method      = var.pkce_code_challenge_method != "" ? var.pkce_code_challenge_method : null

  frontchannel_logout_enabled                = var.front_channel_logout
  backchannel_logout_url                     = var.backchannel_logout_url != "" ? var.backchannel_logout_url : null
  backchannel_logout_session_required        = var.backchannel_logout_session_required
  backchannel_logout_revoke_offline_sessions = var.backchannel_logout_revoke_offline_sessions

  # When null, Keycloak generates a secret for confidential clients.
  client_secret = var.client_secret
}

resource "keycloak_openid_client_default_scopes" "this" {
  count = local.is_oidc ? 1 : 0

  realm_id  = local.realm_id
  client_id = keycloak_openid_client.this[0].id

  default_scopes = var.default_scopes
}

resource "keycloak_openid_client_optional_scopes" "this" {
  count = local.is_oidc && length(var.optional_scopes) > 0 ? 1 : 0

  realm_id  = local.realm_id
  client_id = keycloak_openid_client.this[0].id

  optional_scopes = var.optional_scopes
}
