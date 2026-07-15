locals {
  # Resolve Realm ID from creation or lookup
  realm_id = var.create_realm ? keycloak_realm.this[0].id : data.keycloak_realm.this[0].id

  # Fallback client name
  client_name = var.client_name != null ? var.client_name : var.client_id

  # Certificate resolution strategy
  signing_certificate = var.certificate_strategy == "existing" || var.certificate_strategy == "vault" ? var.saml_signing_certificate : (
    var.certificate_strategy == "generate" ? tls_self_signed_cert.this[0].cert_pem : null
  )

  signing_private_key = var.certificate_strategy == "existing" || var.certificate_strategy == "vault" ? var.saml_private_key : (
    var.certificate_strategy == "generate" ? tls_private_key.this[0].private_key_pem : null
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
}
