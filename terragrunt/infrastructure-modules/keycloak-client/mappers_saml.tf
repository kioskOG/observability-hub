# Standard SAML property mappers (email, username, names, role list).
# Only provisioned when client_protocol = "saml".

resource "keycloak_saml_user_property_protocol_mapper" "email" {
  count = local.is_saml ? 1 : 0

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = "email"
  user_property              = "email"
  saml_attribute_name        = var.email_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Email Address"
}

resource "keycloak_saml_user_property_protocol_mapper" "username" {
  count = local.is_saml ? 1 : 0

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = "username"
  user_property              = "username"
  saml_attribute_name        = var.username_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Username"
}

resource "keycloak_saml_user_property_protocol_mapper" "first_name" {
  count = local.is_saml ? 1 : 0

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = "firstName"
  user_property              = "firstName"
  saml_attribute_name        = var.first_name_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "First Name"
}

resource "keycloak_saml_user_property_protocol_mapper" "last_name" {
  count = local.is_saml ? 1 : 0

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = "lastName"
  user_property              = "lastName"
  saml_attribute_name        = var.last_name_attribute_name
  saml_attribute_name_format = "Basic"
  friendly_name              = "Last Name"
}

# Role-list mapper (Single Role Attribute = true). Name kept configurable for BC (Wazuh).
resource "keycloak_generic_protocol_mapper" "roles" {
  count = local.is_saml ? 1 : 0

  realm_id        = local.realm_id
  client_id       = local.client_uuid
  name            = var.roles_mapper_name
  protocol        = "saml"
  protocol_mapper = "saml-role-list-mapper"

  config = {
    "attribute.name"       = var.roles_attribute_name
    "attribute.nameformat" = "Basic"
    "friendly.name"        = var.roles_attribute_name
    "single"               = "true"
  }
}
