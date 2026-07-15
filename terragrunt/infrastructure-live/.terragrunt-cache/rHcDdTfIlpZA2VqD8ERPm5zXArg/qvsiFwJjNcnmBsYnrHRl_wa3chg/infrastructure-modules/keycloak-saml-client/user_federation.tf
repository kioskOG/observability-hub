# LDAP / Active Directory User Federation
# Provisioned conditionally when var.ldap_federation.enabled is true

resource "keycloak_ldap_user_federation" "this" {
  count = try(var.ldap_federation.enabled, false) ? 1 : 0

  realm_id        = local.realm_id
  name            = lookup(var.ldap_federation, "name", "ldap-federation")
  connection_url  = var.ldap_federation.connection_url
  users_dn        = var.ldap_federation.users_dn
  bind_dn         = var.ldap_federation.bind_dn
  bind_credential = local.resolved_ldap_credential

  username_ldap_attribute = lookup(var.ldap_federation, "username_ldap_attribute", "cn")
  rdn_ldap_attribute      = lookup(var.ldap_federation, "rdn_ldap_attribute", "cn")
  uuid_ldap_attribute     = lookup(var.ldap_federation, "uuid_ldap_attribute", "entryUUID")
  user_object_classes     = lookup(var.ldap_federation, "user_object_classes", ["inetOrgPerson", "organizationalPerson"])
  
  import_enabled     = lookup(var.ldap_federation, "import_enabled", true)
  sync_registrations = lookup(var.ldap_federation, "sync_registrations", false)
  edit_mode          = lookup(var.ldap_federation, "edit_mode", "READ_ONLY")
  vendor             = lookup(var.ldap_federation, "vendor", "other")
}
