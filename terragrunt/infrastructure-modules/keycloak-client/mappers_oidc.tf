# Extensible OIDC protocol mappers (var.oidc_mappers).
# Prefer protocol_mapper + config for arbitrary Keycloak mapper types.
# Optional mapper_type shortcuts for common OIDC claim mappings.

resource "keycloak_openid_user_attribute_protocol_mapper" "oidc_user_attributes" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "user_attribute"
  } : {}

  realm_id            = local.realm_id
  client_id           = local.client_uuid
  name                = each.key
  user_attribute      = each.value.user_attribute
  claim_name          = coalesce(try(each.value.claim_name, null), each.key)
  claim_value_type    = try(each.value.claim_value_type, "String")
  add_to_id_token     = try(each.value.add_to_id_token, true)
  add_to_access_token = try(each.value.add_to_access_token, true)
  add_to_userinfo     = try(each.value.add_to_userinfo, true)
}

resource "keycloak_openid_user_property_protocol_mapper" "oidc_user_properties" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "user_property"
  } : {}

  realm_id            = local.realm_id
  client_id           = local.client_uuid
  name                = each.key
  user_property       = each.value.user_property
  claim_name          = coalesce(try(each.value.claim_name, null), each.key)
  claim_value_type    = try(each.value.claim_value_type, "String")
  add_to_id_token     = try(each.value.add_to_id_token, true)
  add_to_access_token = try(each.value.add_to_access_token, true)
  add_to_userinfo     = try(each.value.add_to_userinfo, true)
}

resource "keycloak_openid_group_membership_protocol_mapper" "oidc_groups" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "group_membership"
  } : {}

  realm_id            = local.realm_id
  client_id           = local.client_uuid
  name                = each.key
  claim_name          = coalesce(try(each.value.claim_name, null), each.key)
  full_path           = try(each.value.full_path, false)
  add_to_id_token     = try(each.value.add_to_id_token, true)
  add_to_access_token = try(each.value.add_to_access_token, true)
  add_to_userinfo     = try(each.value.add_to_userinfo, true)
}

resource "keycloak_openid_audience_protocol_mapper" "oidc_audience" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "audience"
  } : {}

  realm_id                 = local.realm_id
  client_id                = local.client_uuid
  name                     = each.key
  included_client_audience = try(each.value.included_client_audience, null)
  included_custom_audience = try(each.value.included_custom_audience, null)
  add_to_id_token          = try(each.value.add_to_id_token, true)
  add_to_access_token      = try(each.value.add_to_access_token, true)
}

resource "keycloak_openid_hardcoded_claim_protocol_mapper" "oidc_hardcoded" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "hardcoded_claim"
  } : {}

  realm_id            = local.realm_id
  client_id           = local.client_uuid
  name                = each.key
  claim_name          = coalesce(try(each.value.claim_name, null), each.key)
  claim_value         = each.value.claim_value
  claim_value_type    = try(each.value.claim_value_type, "String")
  add_to_id_token     = try(each.value.add_to_id_token, true)
  add_to_access_token = try(each.value.add_to_access_token, true)
  add_to_userinfo     = try(each.value.add_to_userinfo, true)
}

resource "keycloak_openid_user_realm_role_protocol_mapper" "oidc_realm_roles" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "realm_role"
  } : {}

  realm_id            = local.realm_id
  client_id           = local.client_uuid
  name                = each.key
  claim_name          = coalesce(try(each.value.claim_name, null), each.key)
  claim_value_type    = try(each.value.claim_value_type, "String")
  multivalued         = try(each.value.multivalued, true)
  add_to_id_token     = try(each.value.add_to_id_token, true)
  add_to_access_token = try(each.value.add_to_access_token, true)
  add_to_userinfo     = try(each.value.add_to_userinfo, true)
}

resource "keycloak_openid_user_client_role_protocol_mapper" "oidc_client_roles" {
  for_each = local.is_oidc ? {
    for k, v in local.oidc_mappers_typed : k => v
    if v.mapper_type == "client_role"
  } : {}

  realm_id                    = local.realm_id
  client_id                   = local.client_uuid
  name                        = each.key
  claim_name                  = coalesce(try(each.value.claim_name, null), each.key)
  claim_value_type            = try(each.value.claim_value_type, "String")
  multivalued                 = try(each.value.multivalued, true)
  client_id_for_role_mappings = try(each.value.client_id_for_role_mappings, null)
  add_to_id_token             = try(each.value.add_to_id_token, true)
  add_to_access_token         = try(each.value.add_to_access_token, true)
  add_to_userinfo             = try(each.value.add_to_userinfo, true)
}

# Fully extensible: any Keycloak OIDC protocol_mapper id + raw config map
resource "keycloak_generic_protocol_mapper" "oidc_extensible" {
  for_each = local.is_oidc ? local.oidc_mappers_generic : {}

  realm_id        = local.realm_id
  client_id       = local.client_uuid
  name            = each.key
  protocol        = "openid-connect"
  protocol_mapper = each.value.protocol_mapper
  config          = each.value.config
}
