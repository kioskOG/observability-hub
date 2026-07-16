provider "keycloak" {
  client_id = "admin-cli"
  url       = "http://localhost:8080"
}

module "keycloak_saml_argocd" {
  source = "../../"

  keycloak_base_url = "http://localhost:8080"
  realm_name        = "company"
  create_realm      = false
  client_id         = "argocd"
  client_name       = "ArgoCD GitOps Dashboard"

  valid_redirect_uris        = ["https://argocd.int.generic.com/auth/callback"]
  master_saml_processing_url = "https://argocd.int.generic.com/auth/callback"

  roles = [
    "admin",
    "readonly"
  ]

  groups = {
    argocd_admins = {
      roles = ["admin"]
    }
    argocd_users = {
      roles = ["readonly"]
    }
  }

  groups_attribute_name = "groups"
}
