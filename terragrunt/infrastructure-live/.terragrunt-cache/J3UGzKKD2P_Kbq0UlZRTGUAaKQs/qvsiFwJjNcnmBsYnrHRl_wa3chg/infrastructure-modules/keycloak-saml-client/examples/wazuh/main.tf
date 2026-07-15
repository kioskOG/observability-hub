provider "keycloak" {
  client_id = "admin-cli"
  url       = "http://localhost:8080"
}

module "keycloak_saml_wazuh" {
  source = "../../"
  region = "us-east-1"

  keycloak_base_url = "http://localhost:8080"
  keycloak_username = "admin"
  keycloak_password = "password"
  realm_name        = "Wazuh"
  create_realm      = true
  client_id         = "wazuh-saml"
  client_name       = "Wazuh SSO"

  valid_redirect_uris = [
    "https://wazuh.int.generic.com/*"
  ]
  idp_initiated_sso_url_name = "wazuh-dashboard"
  master_saml_processing_url = "https://wazuh.int.generic.com/_opendistro/_security/saml/acs"
  name_id_format             = "username"
  force_name_id_format       = false
  use_realm_roles            = true

  roles = [
    "wazuh-admins",
    "wazuh-readonly"
  ]

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

  # Provision test users as per the Wazuh integration guide
  users = {
    wazuh-user = {
      email            = "wazuh-user@company.com"
      first_name       = "Wazuh"
      last_name        = "User"
      password         = "password"
      temporary_pass   = true
      groups           = ["Wazuh-admins"]
      email_verified   = true
      required_actions = ["UPDATE_PASSWORD"]
    }
  }
}
