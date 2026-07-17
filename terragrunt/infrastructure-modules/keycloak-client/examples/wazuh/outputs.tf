output "client" {
  value = module.keycloak_wazuh.client
}

output "endpoints" {
  value = module.keycloak_wazuh.endpoints
}

output "saml" {
  value = module.keycloak_wazuh.saml
}

# Deprecated flat aliases still work:
output "idp_metadata_url" {
  value = module.keycloak_wazuh.idp_metadata_url
}
