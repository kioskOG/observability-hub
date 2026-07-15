output "idp_metadata_url" {
  value = module.keycloak_saml_wazuh.idp_metadata_url
}

output "idp_entity_id" {
  value = module.keycloak_saml_wazuh.idp_entity_id
}

output "sp_entity_id" {
  value = module.keycloak_saml_wazuh.sp_entity_id
}
