# Realm-Level Groups and Group-to-Client-Role mappings

resource "keycloak_group" "groups" {
  for_each = toset(local.group_names)
  realm_id = local.realm_id
  name     = each.value
}

resource "keycloak_group_roles" "mappings" {
  for_each = var.groups
  realm_id = local.realm_id
  group_id = keycloak_group.groups[each.key].id
  role_ids = [
    for role_name in each.value.roles : keycloak_role.client_roles[role_name].id
  ]
}
