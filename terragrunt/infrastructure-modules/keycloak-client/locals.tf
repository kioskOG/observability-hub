locals {
  is_saml = var.client_protocol == "saml"
  is_oidc = var.client_protocol == "openid-connect"

  # Resolve Realm ID from creation or lookup
  realm_id = var.create_realm ? keycloak_realm.this[0].id : data.keycloak_realm.this[0].id

  # Fallback client name
  client_name = var.client_name != null ? var.client_name : var.client_id

  # Internal Keycloak client UUID used by roles / mappers / scopes
  client_uuid = local.is_saml ? keycloak_saml_client.this[0].id : keycloak_openid_client.this[0].id

  # Certificate resolution (SAML signing only)
  signing_certificate = !local.is_saml ? null : (
    var.certificate_strategy == "existing" || var.certificate_strategy == "vault" ? var.saml_signing_certificate : (
      var.certificate_strategy == "generate" ? tls_self_signed_cert.this[0].cert_pem : null
    )
  )

  signing_private_key = !local.is_saml ? null : (
    var.certificate_strategy == "existing" || var.certificate_strategy == "vault" ? var.saml_private_key : (
      var.certificate_strategy == "generate" ? tls_private_key.this[0].private_key_pem : null
    )
  )

  # Collect all unique client roles to provision
  group_referenced_roles = flatten([for g in values(var.groups) : g.roles])
  all_roles              = distinct(concat(var.roles, local.group_referenced_roles))

  # Extract group names to provision
  group_names = keys(var.groups)

  # Compile password policy string for keycloak_realm resource
  password_policy_string = var.password_policy == null ? null : join(" and ", compact([
    try(var.password_policy.length != null ? "length(${var.password_policy.length})" : null, null),
    try(var.password_policy.digits != null ? "digits(${var.password_policy.digits})" : null, null),
    try(var.password_policy.special_chars != null ? "specialChars(${var.password_policy.special_chars})" : null, null),
    try(var.password_policy.upper_case != null ? "upperCase(${var.password_policy.upper_case})" : null, null),
    try(var.password_policy.lower_case != null ? "lowerCase(${var.password_policy.lower_case})" : null, null),
    try(var.password_policy.password_history != null ? "passwordHistory(${var.password_policy.password_history})" : null, null),
    try(var.password_policy.max_age_days != null ? "forceExpiredPasswordChange(${var.password_policy.max_age_days})" : null, null),
    try(var.password_policy.not_username == true ? "notUsername" : null, null),
  ]))

  # --------------------------------------------------------------------------
  # Centralized endpoint construction (single place for URL derivation)
  # --------------------------------------------------------------------------
  keycloak_url = trimsuffix(var.keycloak_base_url, "/")
  realm_base   = "${local.keycloak_url}/realms/${local.realm_id}"
  oidc_base    = "${local.realm_base}/protocol/openid-connect"
  saml_base    = "${local.realm_base}/protocol/saml"

  oidc_endpoints = {
    issuer                   = local.realm_base
    authorization_endpoint   = "${local.oidc_base}/auth"
    token_endpoint           = "${local.oidc_base}/token"
    userinfo_endpoint        = "${local.oidc_base}/userinfo"
    end_session_endpoint     = "${local.oidc_base}/logout"
    jwks_uri                 = "${local.oidc_base}/certs"
    openid_configuration_url = "${local.realm_base}/.well-known/openid-configuration"
  }

  saml_endpoints = {
    idp_entity_id    = local.realm_base
    idp_metadata_url = "${local.saml_base}/descriptor"
    sp_entity_id     = var.client_id
  }

  # Protocol-agnostic structured endpoints object for consumers
  endpoints = local.is_oidc ? local.oidc_endpoints : local.saml_endpoints

  # Merge deprecated advanced_saml_mappers into saml_mappers (saml_mappers wins on key clash)
  effective_saml_mappers = merge(var.advanced_saml_mappers, var.saml_mappers)

  # Typed vs fully-generic SAML mapper split
  saml_mappers_typed = {
    for k, v in local.effective_saml_mappers : k => v
    if try(v.protocol_mapper, null) == null && try(v.mapper_type, null) != null
  }
  saml_mappers_generic = {
    for k, v in local.effective_saml_mappers : k => v
    if try(v.protocol_mapper, null) != null
  }

  oidc_mappers_typed = {
    for k, v in var.oidc_mappers : k => v
    if try(v.protocol_mapper, null) == null && try(v.mapper_type, null) != null
  }
  oidc_mappers_generic = {
    for k, v in var.oidc_mappers : k => v
    if try(v.protocol_mapper, null) != null
  }
}
