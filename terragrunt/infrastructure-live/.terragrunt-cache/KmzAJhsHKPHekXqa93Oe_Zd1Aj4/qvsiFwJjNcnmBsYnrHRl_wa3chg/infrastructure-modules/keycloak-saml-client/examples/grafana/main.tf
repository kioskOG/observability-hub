provider "keycloak" {
  client_id = "admin-cli"
  url       = "http://localhost:8080"
}

module "keycloak_saml_grafana" {
  source = "../../"

  keycloak_base_url = "http://localhost:8080"
  realm_name        = "company"
  create_realm      = false
  client_id         = "grafana"
  client_name       = "Grafana Metrics Dashboard"

  valid_redirect_uris        = ["https://grafana.int.generic.com/login/saml"]
  master_saml_processing_url = "https://grafana.int.generic.com/login/saml"

  roles = [
    "Admin",
    "Editor",
    "Viewer"
  ]

  groups = {
    grafana_admins = {
      roles = ["Admin", "Editor"]
    }
    grafana_editors = {
      roles = ["Editor"]
    }
    grafana_viewers = {
      roles = ["Viewer"]
    }
  }

  groups_attribute_name = "groups"
}
