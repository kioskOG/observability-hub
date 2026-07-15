# Terragrunt deployment configuration for Grafana SAML client on Keycloak

include {
  path = find_in_parent_folders()
}

locals {
  secrets = read_terragrunt_config("secrets.hcl")
}

terraform {
  source = "../../../../../..//infrastructure-modules/keycloak-saml-client"
}

inputs = {
  keycloak_base_url  = "https://keycloak.company.com"
  realm_name         = "company"
  create_realm       = false

  client_id                  = "grafana"
  client_name                = "Grafana Metrics Dashboard"
  valid_redirect_uris        = ["https://grafana.int.generic.com/login/saml"]
  master_saml_processing_url = "https://grafana.int.generic.com/login/saml"
  force_name_id_format       = true
  name_id_format             = "email"

  # Certificate strategy
  certificate_strategy = "generate"

  # Client-level roles
  roles = [
    "Admin",
    "Editor",
    "Viewer"
  ]

  # Realm group to client role mappings
  groups = {
    grafana-admins = {
      roles = ["Admin", "Editor"]
    }
    grafana-editors = {
      roles = ["Editor"]
    }
    grafana-viewers = {
      roles = ["Viewer"]
    }
  }

  groups_attribute_name = "groups"
}
