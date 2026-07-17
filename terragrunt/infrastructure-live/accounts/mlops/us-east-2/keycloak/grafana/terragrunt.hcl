# Terragrunt deployment: Grafana OIDC client on Keycloak (production)
# App-specific roles/groups/mappers live here — the module stays Keycloak-centric.
# Aligns with: https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/keycloak/
# Runbook: Docs/Grafana-SSO-Production.md

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/keycloak-client"
}

locals {
  # Public Grafana URL (must match Grafana server.root_url and ingress DNS/TLS).
  grafana_root_url = "https://grafana.jatinog.com"

  # Dev-only: set true for make pf-grafana SSO, then terragrunt apply.
  # Keep false in production (see Docs/Grafana-SSO-Production.md §5).
  enable_local_oauth_redirects = false

  grafana_local_urls = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
  ]

  oauth_redirect_bases = concat(
    [local.grafana_root_url],
    local.enable_local_oauth_redirects ? local.grafana_local_urls : [],
  )
}

inputs = {
  keycloak_base_url = "https://keycloak.jatinog.com/"
  keycloak_username = "admin"
  realm_name        = "grafana"
  create_realm      = true

  secret_mappings = {
    keycloak_password = {
      secret_arn = "platform/keycloak"
      secret_key = "keycloak_password"
    }
  }

  # Protocol
  client_protocol = "openid-connect"
  client_id       = "grafana-oauth"
  client_name     = "Grafana"
  access_type     = "CONFIDENTIAL"

  # Flows (production-hardened)
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  pkce_code_challenge_method   = "S256"

  root_url    = local.grafana_root_url
  base_url    = local.grafana_root_url
  admin_url   = local.grafana_root_url
  web_origins = local.oauth_redirect_bases

  # Exact match required — Keycloak returns "Invalid parameter: redirect_uri" otherwise.
  valid_redirect_uris = [
    for u in local.oauth_redirect_bases : "${u}/login/generic_oauth"
  ]
  valid_post_logout_redirect_uris = [
    for u in local.oauth_redirect_bases : "${u}/login"
  ]

  # Keycloak client scopes (openid is not a client scope — it is implied by OIDC).
  # Grafana still requests scope=openid in auth.generic_oauth.scopes.
  default_scopes  = ["email", "profile", "roles"]
  optional_scopes = ["offline_access"]

  # Keycloak client roles (Grafana maps via role_attribute_path in Grafana config)
  roles = ["admin", "editor", "viewer"]

  groups = {
    grafana-admins = {
      roles = ["admin", "editor"]
    }
    grafana-editors = {
      roles = ["editor"]
    }
    grafana-viewers = {
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
    # Flat "roles" claim so Grafana role_attribute_path can use roles[*]
    client_roles = {
      mapper_type                 = "client_role"
      claim_name                  = "roles"
      client_id_for_role_mappings = "grafana-oauth"
      multivalued                 = true
      add_to_id_token             = true
      add_to_access_token         = true
      add_to_userinfo             = true
    }
    audience = {
      mapper_type              = "audience"
      included_client_audience = "grafana-oauth"
      add_to_id_token          = true
      add_to_access_token      = true
    }
  }
}
