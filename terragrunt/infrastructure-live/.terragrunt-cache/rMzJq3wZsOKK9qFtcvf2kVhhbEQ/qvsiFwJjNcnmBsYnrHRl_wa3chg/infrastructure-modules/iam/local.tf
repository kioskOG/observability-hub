
locals {
  local_iam_user_managed_policy = flatten([
    for iam_user_key, iam_user_value in var.iam_user : [
      for iam_user_managed_key in iam_user_value.managed_policy : "${iam_user_key}@${iam_user_managed_key}"
    ]
  ])
}
locals {
  local_iam_user_custom_policy = flatten([
    for iam_user_key, iam_user_value in var.iam_user : [
      for iam_user_managed_key in iam_user_value.custom_policy : "${iam_user_key}@${iam_user_managed_key}"
    ]
  ])
}


locals {
  local_iam_role_managed_policy = flatten([
    for iam_role_key, iam_role_value in var.iam_role : [
      for iam_role_custom_key in iam_role_value.managed_policy : "${iam_role_key}@${iam_role_custom_key}"
    ]
  ])
}
locals {
  local_iam_role_custom_policy = flatten([
    for iam_role_key, iam_role_value in var.iam_role : [
      for iam_role_custom_key in iam_role_value.custom_policy : "${iam_role_key}@${iam_role_custom_key}"
    ]
  ])
}

locals {
  local_iam_instance_profile = [
    for role_name, role_config in var.iam_role : role_name
    if lookup(role_config, "instance_profile", false) == true
  ]
}