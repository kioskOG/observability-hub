provider "keycloak" {
  client_id = "admin-cli"
  url       = "http://localhost:8080"
}

# Grafana via OIDC — roles/groups/mappers are Terragrunt (caller) inputs.
# Module has no Grafana-specific hardcoded logic.
module "keycloak_grafana" {
  source = "../../"

  keycloak_base_url = "http://localhost:8080"
  realm_name        = "company"
  create_realm      = false

  client_protocol = "openid-connect"
  client_id       = "grafana-oauth"
  client_name     = "Grafana Metrics Dashboard"
  access_type     = "CONFIDENTIAL"

  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  pkce_code_challenge_method   = "S256"

  root_url    = "https://grafana.int.generic.com"
  base_url    = "https://grafana.int.generic.com"
  admin_url   = "https://grafana.int.generic.com"
  web_origins = ["https://grafana.int.generic.com"]

  valid_redirect_uris             = ["https://grafana.int.generic.com/login/generic_oauth"]
  valid_post_logout_redirect_uris = ["https://grafana.int.generic.com/login"]

  default_scopes  = ["email", "profile", "roles"]
  optional_scopes = ["offline_access"]

  roles = ["admin", "editor", "viewer"]

  groups = {
    grafana_admins = {
      roles = ["admin", "editor"]
    }
    grafana_editors = {
      roles = ["editor"]
    }
    grafana_viewers = {
      roles = ["viewer"]
    }
  }

  oidc_mappers = {
    groups = {
      mapper_type         = "group_membership"
      claim_name          = "groups"
      full_path           = false
      add_to_id_token     = true
      add_to_access_token = false
      add_to_userinfo     = true
    }
  }
}
