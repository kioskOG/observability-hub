# External Identity Providers (OIDC / SAML)
# Provisioned conditionally based on var.external_identity_providers settings

resource "keycloak_oidc_identity_provider" "this" {
  for_each = {
    for k, v in var.external_identity_providers : k => v
    if v.enabled && v.type == "oidc"
  }

  realm             = local.realm_id
  alias             = coalesce(each.value.alias, each.key)
  display_name      = lookup(each.value, "display_name", null)
  client_id         = each.value.client_id
  client_secret     = each.value.client_secret != null ? each.value.client_secret : lookup(local.resolved_secrets, "${each.key}_client_secret", null)
  authorization_url = each.value.authorization_url
  token_url         = each.value.token_url
  user_info_url     = lookup(each.value, "user_info_url", null)
  logout_url        = lookup(each.value, "logout_url", null)
}

resource "keycloak_saml_identity_provider" "this" {
  for_each = {
    for k, v in var.external_identity_providers : k => v
    if v.enabled && v.type == "saml"
  }

  realm                      = local.realm_id
  alias                      = coalesce(each.value.alias, each.key)
  display_name               = lookup(each.value, "display_name", null)
  single_sign_on_service_url = each.value.single_sign_on_service_url
  single_logout_service_url  = lookup(each.value, "single_logout_service_url", null)
  name_id_policy_format      = lookup(each.value, "name_id_policy_format", null)
  entity_id                  = each.value.entity_id
}
