output "idp_metadata_url" {
  value = module.keycloak_saml_grafana.idp_metadata_url
}

output "idp_entity_id" {
  value = module.keycloak_saml_grafana.idp_entity_id
}

output "sp_entity_id" {
  value = module.keycloak_saml_grafana.sp_entity_id
}
