# Terragrunt deployment configuration for Wazuh SAML client on Keycloak
# Aligns with official Wazuh documentation parameters

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/keycloak-saml-client"
}

inputs = {
  keycloak_base_url   = "https://keycloak.jatinog.com/"
  keycloak_username   = "admin"
  secret_mappings = {
    keycloak_password = {
      secret_arn = "platform/keycloak"
      secret_key = "keycloak_password"
    }
    smtp_password = {
      secret_arn = "platform/keycloak"
      secret_key = "smtp_password"
    }
    smtp_host = {
      secret_arn = "platform/keycloak"
      secret_key = "host"
    }
    smtp_port = {
      secret_arn = "platform/keycloak"
      secret_key = "port"
    }
    smtp_from = {
      secret_arn = "platform/keycloak"
      secret_key = "from"
    }
    smtp_username = {
      secret_arn = "platform/keycloak"
      secret_key = "username"
    }
    smtp_starttls = {
      secret_arn = "platform/keycloak"
      secret_key = "starttls"
    }
  }
  #region             = "us-east-2"
  realm_name          = "Wazuh"
  create_realm       = true
  consent_required   = false
  enabled            = true
  
  client_id                  = "wazuh-saml"
  client_name                = "Wazuh SSO"
  valid_redirect_uris        = ["https://wazuh.jatinog.com/*"]
  idp_initiated_sso_url_name = "wazuh-dashboard"
  #master_saml_processing_url = "https://wazuh.jatinog.com/_opendistro/_security/saml/acs"
  force_name_id_format       = false
  force_post_binding         = true
  include_authn_statement    = true
  name_id_format             = "username"
  sign_documents             = true
  sign_assertions            = true
  signature_algorithm        = "RSA_SHA256"
  encrypt_assertions         = false
  signature_key_name         = "KEY_ID"
  canonicalization_method    = "EXCLUSIVE"
  assertion_consumer_post_url = "https://wazuh.jatinog.com/_opendistro/_security/saml/acs/idpinitiated"
  logout_service_redirect_binding_url = "https://wazuh.jatinog.com/"

  # Certificate strategy
  certificate_strategy = "generate"

  # Realm-level roles matching Wazuh backend roles
  use_realm_roles = true
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
  users = {
    jatin = {
      email            = "jatin@company.com"
      first_name       = "jatin"
      last_name        = "User"
      password         = "password@12345678"
      temporary_pass   = true
      groups           = ["Wazuh-admins"]
      required_actions = ["UPDATE_PASSWORD"]
    },
    kiosk = {
      email            = "js839624@gmail.com"
      first_name       = "Kiosk"
      last_name        = "User"
      password         = "password@12345678"
      temporary_pass   = true
      groups           = ["Wazuh-admins"]
      required_actions = ["UPDATE_PASSWORD"]
      email_verified   = false
    }
  }

  # 1. Password Policies
  password_policy = {
    length       = 14
    digits       = 1
    not_username = true
  }

  # 2. Multi-Factor Authentication
  mfa = {
    enabled = true
    methods = ["totp"]
  }

  # 3. Advanced SAML Mappers
  # advanced_saml_mappers = {
  #   department = {
  #    mapper_type    = "user_attribute"
  #    user_attribute = "department"
  #   saml_attribute = "department"
  #  }
  #}

  # 4. SMTP Settings (Configured dynamically inside the module via secrets_manager_arn)
  smtp = null
}
