output "client" {
  value = module.keycloak_grafana.client
}

output "endpoints" {
  value = module.keycloak_grafana.endpoints
}

output "client_secret" {
  value     = module.keycloak_grafana.client_secret
  sensitive = true
}
