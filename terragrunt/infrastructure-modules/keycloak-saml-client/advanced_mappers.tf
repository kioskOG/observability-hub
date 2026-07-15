# Advanced SAML Protocol Mappers
# Provisioned conditionally based on var.advanced_saml_mappers inputs

# User Attribute Mappers
resource "keycloak_saml_user_attribute_protocol_mapper" "advanced_user_attributes" {
  for_each = {
    for k, v in var.advanced_saml_mappers : k => v
    if v.mapper_type == "user_attribute"
  }

  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = each.key
  user_attribute             = each.value.user_attribute
  saml_attribute_name        = each.value.saml_attribute
  saml_attribute_name_format = "Basic"
  friendly_name              = lookup(each.value, "friendly_name", null)
}

# User Property Mappers
resource "keycloak_saml_user_property_protocol_mapper" "advanced_user_properties" {
  for_each = {
    for k, v in var.advanced_saml_mappers : k => v
    if v.mapper_type == "user_property"
  }

  realm_id                   = local.realm_id
  client_id                  = keycloak_saml_client.this.id
  name                       = each.key
  user_property              = each.value.user_property
  saml_attribute_name        = each.value.saml_attribute
  saml_attribute_name_format = "Basic"
  friendly_name              = lookup(each.value, "friendly_name", null)
}

# Generic Protocol Mappers (for Group, Role, and Hardcoded Attribute mapping types)
resource "keycloak_generic_protocol_mapper" "advanced_generic" {
  for_each = {
    for k, v in var.advanced_saml_mappers : k => v
    if contains(["group", "role", "hardcoded_attribute"], v.mapper_type)
  }

  realm_id        = local.realm_id
  client_id       = keycloak_saml_client.this.id
  name            = each.key
  protocol        = "saml"
  protocol_mapper = (
    each.value.mapper_type == "group" ? "saml-group-membership-mapper" : (
      each.value.mapper_type == "role" ? "saml-role-list-mapper" : "saml-hardcode-attribute-mapper"
    )
  )

  config = (
    each.value.mapper_type == "group" ? {
      "attribute.name"       = coalesce(each.value.saml_attribute, each.key)
      "attribute.nameformat" = "Basic"
      "friendly.name"        = coalesce(each.value.saml_attribute, each.key)
      "full.path"            = "false"
      "single"               = "true"
    } : (
      each.value.mapper_type == "role" ? {
        "attribute.name"       = coalesce(each.value.saml_attribute, each.key)
        "attribute.nameformat" = "Basic"
        "friendly.name"        = coalesce(each.value.saml_attribute, each.key)
        "single"               = "true"
      } : {
        "attribute.name"       = coalesce(each.value.saml_attribute, each.key)
        "attribute.value"      = each.value.attribute_value
        "saml.attribute"       = coalesce(each.value.saml_attribute, each.key)
        "attribute.nameformat" = "Basic"
      }
    )
  )
}
