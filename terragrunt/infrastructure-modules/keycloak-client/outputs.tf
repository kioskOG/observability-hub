# Structured outputs (preferred). Flat SAML outputs retained for backward compatibility.

output "client" {
  description = "Keycloak client identity (protocol-agnostic)"
  value = {
    protocol    = var.client_protocol
    client_id   = var.client_id
    client_uuid = local.client_uuid
    name        = local.client_name
    realm       = local.realm_id
  }
}

output "client_secret" {
  description = "OIDC client secret (null for SAML / public clients)"
  value       = local.is_oidc ? try(keycloak_openid_client.this[0].client_secret, null) : null
  sensitive   = true
}

output "endpoints" {
  description = "Protocol endpoints derived centrally from keycloak_base_url + realm (see locals.endpoints)"
  value       = local.endpoints
}

output "oidc" {
  description = "OIDC endpoint bundle (null when client_protocol != openid-connect)"
  value       = local.is_oidc ? local.oidc_endpoints : null
}

output "saml" {
  description = "SAML endpoint bundle (null when client_protocol != saml)"
  value       = local.is_saml ? local.saml_endpoints : null
}

output "realm_name" {
  description = "The name of the realm used"
  value       = local.realm_id
}

output "client_roles" {
  description = "List of created roles (client or realm-scoped)"
  value       = [for r in keycloak_role.client_roles : r.name]
}

output "groups" {
  description = "List of created realm groups"
  value       = [for g in keycloak_group.groups : g.name]
}

output "users" {
  description = "List of created realm users"
  value       = [for u in keycloak_user.users : u.username]
}

output "signing_certificate" {
  description = "The SAML signing certificate (PEM format); null for OIDC"
  value       = local.signing_certificate
  sensitive   = true
}

# --- Deprecated flat SAML aliases (prefer output.saml / output.endpoints) ---

output "idp_metadata_url" {
  description = "DEPRECATED: use endpoints.idp_metadata_url or saml.idp_metadata_url"
  value       = try(local.saml_endpoints.idp_metadata_url, null)
}

output "idp_entity_id" {
  description = "DEPRECATED: use endpoints.idp_entity_id or saml.idp_entity_id"
  value       = try(local.saml_endpoints.idp_entity_id, null)
}

output "sp_entity_id" {
  description = "DEPRECATED: use endpoints.sp_entity_id or saml.sp_entity_id"
  value       = try(local.saml_endpoints.sp_entity_id, null)
}
