# Terragrunt deployment configuration for Wazuh SAML client on Keycloak
# Aligns with official Wazuh documentation parameters

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
  realm_name         = "Wazuh"
  create_realm       = false

  client_id                  = "wazuh-saml"
  client_name                = "Wazuh SSO"
  valid_redirect_uris        = ["https://wazuh.int.generic.com/*"]
  master_saml_processing_url = "https://wazuh.int.generic.com/_opendistro/_security/saml/acs"
  force_name_id_format       = true
  name_id_format             = "username"

  # Certificate strategy
  certificate_strategy = "generate"

  # Client-level roles matching Wazuh backend roles
  roles = [
    "wazuh-admins",
    "wazuh-readonly"
  ]

  # Realm group to client role mappings
  groups = {
    "Wazuh-admins" = {
      roles = ["wazuh-admins"]
    }
    "Wazuh read only" = {
      roles = ["wazuh-readonly"]
    }
  }

  groups_attribute_name = "Roles"
  roles_attribute_name  = "Roles"

  # Realm users (can be left empty if using LDAP/Active Directory federation)
  users = {}
}
