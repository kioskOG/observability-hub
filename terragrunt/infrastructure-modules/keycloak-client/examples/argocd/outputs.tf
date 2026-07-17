output "client" {
  value = module.keycloak_argocd.client
}

output "endpoints" {
  value = module.keycloak_argocd.endpoints
}

output "client_secret" {
  value     = module.keycloak_argocd.client_secret
  sensitive = true
}
