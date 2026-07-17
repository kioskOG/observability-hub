# Client or Realm-Level Roles
# Roles are created using the union of var.roles and group-referenced roles.

resource "keycloak_role" "client_roles" {
  for_each  = toset(local.all_roles)
  realm_id  = local.realm_id
  client_id = var.use_realm_roles ? null : local.client_uuid
  name      = each.value
}
