# Extensible SAML protocol mappers (var.saml_mappers).
# Prefer protocol_mapper + config for arbitrary Keycloak mapper types.
# Optional mapper_type shortcuts remain for common cases.
# DEPRECATED alias: advanced_saml_mappers (merged in locals.effective_saml_mappers).

resource "keycloak_saml_user_attribute_protocol_mapper" "saml_user_attributes" {
  for_each = local.is_saml ? {
    for k, v in local.saml_mappers_typed : k => v
    if v.mapper_type == "user_attribute"
  } : {}

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = each.key
  user_attribute             = each.value.user_attribute
  saml_attribute_name        = coalesce(try(each.value.saml_attribute, null), each.key)
  saml_attribute_name_format = "Basic"
  friendly_name              = try(each.value.friendly_name, null)
}

resource "keycloak_saml_user_property_protocol_mapper" "saml_user_properties" {
  for_each = local.is_saml ? {
    for k, v in local.saml_mappers_typed : k => v
    if v.mapper_type == "user_property"
  } : {}

  realm_id                   = local.realm_id
  client_id                  = local.client_uuid
  name                       = each.key
  user_property              = each.value.user_property
  saml_attribute_name        = coalesce(try(each.value.saml_attribute, null), each.key)
  saml_attribute_name_format = "Basic"
  friendly_name              = try(each.value.friendly_name, null)
}

# Typed shortcuts that map to generic protocol mappers
resource "keycloak_generic_protocol_mapper" "saml_typed_generic" {
  for_each = local.is_saml ? {
    for k, v in local.saml_mappers_typed : k => v
    if contains(["group", "role", "hardcoded_attribute"], v.mapper_type)
  } : {}

  realm_id  = local.realm_id
  client_id = local.client_uuid
  name      = each.key
  protocol  = "saml"
  protocol_mapper = (
    each.value.mapper_type == "group" ? "saml-group-membership-mapper" : (
      each.value.mapper_type == "role" ? "saml-role-list-mapper" : "saml-hardcode-attribute-mapper"
    )
  )

  config = merge(
    each.value.mapper_type == "group" ? {
      "attribute.name"       = coalesce(try(each.value.saml_attribute, null), each.key)
      "attribute.nameformat" = "Basic"
      "friendly.name"        = coalesce(try(each.value.saml_attribute, null), each.key)
      "full.path"            = "false"
      "single"               = "true"
      } : each.value.mapper_type == "role" ? {
      "attribute.name"       = coalesce(try(each.value.saml_attribute, null), each.key)
      "attribute.nameformat" = "Basic"
      "friendly.name"        = coalesce(try(each.value.saml_attribute, null), each.key)
      "single"               = "true"
      } : {
      "attribute.name"       = coalesce(try(each.value.saml_attribute, null), each.key)
      "attribute.value"      = each.value.attribute_value
      "saml.attribute"       = coalesce(try(each.value.saml_attribute, null), each.key)
      "attribute.nameformat" = "Basic"
    },
    try(each.value.config, {})
  )
}

# Fully extensible: any Keycloak SAML protocol_mapper id + raw config map
resource "keycloak_generic_protocol_mapper" "saml_extensible" {
  for_each = local.is_saml ? local.saml_mappers_generic : {}

  realm_id        = local.realm_id
  client_id       = local.client_uuid
  name            = each.key
  protocol        = "saml"
  protocol_mapper = each.value.protocol_mapper
  config          = each.value.config
}
