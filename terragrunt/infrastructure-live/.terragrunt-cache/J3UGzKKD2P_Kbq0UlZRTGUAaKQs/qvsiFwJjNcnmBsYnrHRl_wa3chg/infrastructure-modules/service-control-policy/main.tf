#########################################################
## This resource block will help user to create Policy ##
#########################################################

resource "aws_organizations_policy" "example" {
  for_each = local.local_policy_list
  name     = each.key
  type     = "SERVICE_CONTROL_POLICY"
  # content = file("policies/${each.key}.json")
  content = data.aws_iam_policy_document.b[each.key].json
}

##################################################################
## This resource block will help to attach policy to Account id ##
##################################################################

resource "aws_organizations_policy_attachment" "account" {
  for_each  = toset(local.attchement_var)
  policy_id = aws_organizations_policy.example[split("@", each.key)[1]].id
  target_id = split("@", each.key)[0]
}

#########################################################################
## This resource block will help to attach policy to Organization Unit ##
#########################################################################

## Inprogress