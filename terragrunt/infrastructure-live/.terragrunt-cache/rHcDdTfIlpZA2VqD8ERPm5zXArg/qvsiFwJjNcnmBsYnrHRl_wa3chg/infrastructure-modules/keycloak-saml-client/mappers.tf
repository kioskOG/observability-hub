# SAML Protocol Mappers
#
# NOTE ON PROVIDER LIMITATIONS:
# The mrparkers/keycloak provider does not have dedicated resources for:
# - SAML Group Membership protocol mappers
# - SAML Role List protocol mappers
# To bypass this limitation, we use `keycloak_generic_protocol_mapper` for those resources,
# configuring the `protocol_mapper` field to Keycloak's internal names:
# - "saml-group-membership-mapper"
# - "saml-role-list-mapper"

# Email Property Mapper
resource "keycloak_saml_user_property_protocol_mapper" "email" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = "email"
  user_property              = "email"
  saml_attribute_name        = var.email_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Email Address"
}

# Username Property Mapper
resource "keycloak_saml_user_property_protocol_mapper" "username" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = "username"
  user_property              = "username"
  saml_attribute_name        = var.username_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Username"
}

# First Name Property Mapper
resource "keycloak_saml_user_property_protocol_mapper" "first_name" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = "firstName"
  user_property              = "firstName"
  saml_attribute_name        = var.first_name_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "First Name"
}

# Last Name Property Mapper
resource "keycloak_saml_user_property_protocol_mapper" "last_name" {
  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = "lastName"
  user_property              = "lastName"
  saml_attribute_name        = var.last_name_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Last Name"
}



# ---------------------------------------------------------------------------
# Role list mapper — per official Wazuh + Keycloak documentation
#
# Attached directly to this SAML client's dedicated scope.
# The built-in 'role_list' Client Scope (which has a default role list mapper
# with single=false causing duplicate Attribute Name errors) is blocked from
# attaching to this client via the keycloak_saml_client_default_scopes
# resource in main.tf (default_scopes = []).
#
# This mapper emits roles under attribute name "Roles" with Single Role
# Attribute = On, matching roles_key: Roles in the Wazuh indexer config.yml.
# ---------------------------------------------------------------------------
resource "keycloak_generic_protocol_mapper" "roles" {
  realm_id        = local.realm_id
  client_id       = keycloak_saml_client.this.id
  name            = "wazuhRoleKey"
  protocol        = "saml"
  protocol_mapper = "saml-role-list-mapper"

  config = {
    "attribute.name"       = var.roles_attribute_name  # "Roles" — matches roles_key in config.yml
    "attribute.nameformat" = "Basic"
    "friendly.name"        = var.roles_attribute_name
    # Single Role Attribute = true → all roles in ONE <saml:Attribute> element
    # Prevents "Found an Attribute element with duplicated Name" in java-saml
    "single"               = "true"
  }
}
