# Realm-Level Users and User-to-Group memberships

resource "keycloak_user" "users" {
  for_each   = var.users
  realm_id   = local.realm_id
  username   = each.key
  email      = each.value.email
  first_name = each.value.first_name
  last_name  = each.value.last_name
  enabled    = true

  initial_password {
    value     = each.value.password
    temporary = each.value.temporary_pass
  }
  email_verified   = each.value.email_verified
  required_actions = each.value.required_actions
}

resource "keycloak_user_groups" "user_groups" {
  for_each = var.users
  realm_id = local.realm_id
  user_id  = keycloak_user.users[each.key].id
  group_ids = [
    for group_name in each.value.groups : keycloak_group.groups[group_name].id
  ]
}
