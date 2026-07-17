# State address migrations for SAML resources that gained count / were renamed.
# Required so existing Wazuh (and other SAML) deployments plan with zero drift
# when migrating from keycloak-saml-client (uncounted) → keycloak-client (counted).

moved {
  from = keycloak_saml_client.this
  to   = keycloak_saml_client.this[0]
}

moved {
  from = keycloak_saml_client_default_scopes.default_scopes
  to   = keycloak_saml_client_default_scopes.default_scopes[0]
}

moved {
  from = keycloak_saml_user_property_protocol_mapper.email
  to   = keycloak_saml_user_property_protocol_mapper.email[0]
}

moved {
  from = keycloak_saml_user_property_protocol_mapper.username
  to   = keycloak_saml_user_property_protocol_mapper.username[0]
}

moved {
  from = keycloak_saml_user_property_protocol_mapper.first_name
  to   = keycloak_saml_user_property_protocol_mapper.first_name[0]
}

moved {
  from = keycloak_saml_user_property_protocol_mapper.last_name
  to   = keycloak_saml_user_property_protocol_mapper.last_name[0]
}

moved {
  from = keycloak_generic_protocol_mapper.roles
  to   = keycloak_generic_protocol_mapper.roles[0]
}

moved {
  from = null_resource.delete_role_list_mapper
  to   = null_resource.delete_role_list_mapper[0]
}

# Renamed advanced_* mapper resources → protocol-named saml_* resources
moved {
  from = keycloak_saml_user_attribute_protocol_mapper.advanced_user_attributes
  to   = keycloak_saml_user_attribute_protocol_mapper.saml_user_attributes
}

moved {
  from = keycloak_saml_user_property_protocol_mapper.advanced_user_properties
  to   = keycloak_saml_user_property_protocol_mapper.saml_user_properties
}

moved {
  from = keycloak_generic_protocol_mapper.advanced_generic
  to   = keycloak_generic_protocol_mapper.saml_typed_generic
}
