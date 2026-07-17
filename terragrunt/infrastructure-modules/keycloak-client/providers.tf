# Providers declaration for keycloak-client module
# Provider configuration must be passed from the parent caller (Terragrunt or root module).

provider "keycloak" {
  client_id     = "admin-cli"
  username      = var.keycloak_username
  password      = local.resolved_keycloak_password
  url           = var.keycloak_base_url
  initial_login = false
}
