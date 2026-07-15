# Terragrunt deployment configuration for ArgoCD SAML client on Keycloak

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

  client_id                  = "argocd"
  client_name                = "ArgoCD GitOps Dashboard"
  valid_redirect_uris        = ["https://argocd.int.generic.com/auth/callback"]
  master_saml_processing_url = "https://argocd.int.generic.com/auth/callback"
  force_name_id_format       = true
  name_id_format             = "email"

  # Certificate strategy
  certificate_strategy = "generate"

  # Client-level roles
  roles = [
    "admin",
    "readonly"
  ]

  # Realm group to client role mappings
  groups = {
    argocd-admins = {
      roles = ["admin"]
    }
    argocd-users = {
      roles = ["readonly"]
    }
  }

  groups_attribute_name = "groups"
}
