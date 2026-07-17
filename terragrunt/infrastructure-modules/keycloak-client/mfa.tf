# MFA Required Actions
# Configured conditionally when mfa.enabled is true

resource "keycloak_required_action" "totp" {
  count          = try(var.mfa.enabled, false) && contains(try(var.mfa.methods, []), "totp") ? 1 : 0
  realm_id       = local.realm_id
  alias          = "CONFIGURE_TOTP"
  enabled        = true
  default_action = contains(try(var.mfa.required_for, []), "all")
}

resource "keycloak_required_action" "webauthn" {
  count          = try(var.mfa.enabled, false) && contains(try(var.mfa.methods, []), "webauthn") ? 1 : 0
  realm_id       = local.realm_id
  alias          = "webauthn-register"
  enabled        = true
  default_action = contains(try(var.mfa.required_for, []), "all")
}
