output "idp_metadata_url" {
  description = "The XML Metadata URL of the Keycloak Identity Provider (IdP)"
  value       = "${var.keycloak_base_url}/realms/${local.realm_id}/protocol/saml/descriptor"
}

output "idp_entity_id" {
  description = "The Entity ID of the Keycloak Identity Provider (IdP)"
  value       = "${var.keycloak_base_url}/realms/${local.realm_id}"
}

output "sp_entity_id" {
  description = "The Entity ID of the Service Provider (SP), which is the client ID in Keycloak"
  value       = keycloak_saml_client.this.client_id
}

output "realm_name" {
  description = "The name of the realm used"
  value       = local.realm_id
}

output "signing_certificate" {
  description = "The SAML signing certificate (PEM format)"
  value       = local.signing_certificate
  sensitive   = true
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
  description = "List of created realm groups"
  value       = [for u in keycloak_user.users : u.username]
}
