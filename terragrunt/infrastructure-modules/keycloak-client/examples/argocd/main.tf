provider "keycloak" {
  client_id = "admin-cli"
  url       = "http://localhost:8080"
}

# ArgoCD via OIDC — same generic module; app config via inputs only.
module "keycloak_argocd" {
  source = "../../"

  keycloak_base_url = "http://localhost:8080"
  realm_name        = "company"
  create_realm      = false

  client_protocol = "openid-connect"
  client_id       = "argocd"
  client_name     = "ArgoCD GitOps Dashboard"
  access_type     = "CONFIDENTIAL"

  standard_flow_enabled      = true
  pkce_code_challenge_method = "S256"

  root_url    = "https://argocd.int.generic.com"
  web_origins = ["https://argocd.int.generic.com"]
  valid_redirect_uris = [
    "https://argocd.int.generic.com/auth/callback"
  ]

  default_scopes  = ["profile", "email", "groups"]
  optional_scopes = ["offline_access"]

  roles = ["admin", "readonly"]

  groups = {
    argocd_admins = {
      roles = ["admin"]
    }
    argocd_users = {
      roles = ["readonly"]
    }
  }

  oidc_mappers = {
    groups = {
      mapper_type = "group_membership"
      claim_name  = "groups"
      full_path   = false
    }
  }
}
