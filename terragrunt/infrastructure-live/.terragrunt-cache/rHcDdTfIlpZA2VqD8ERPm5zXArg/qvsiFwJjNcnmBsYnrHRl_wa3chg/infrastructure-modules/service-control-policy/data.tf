
# data "template_file" "test" {
#   for_each = toset(var.organizations_policy_name)
#   template = file("${path.module}/templates/${each.key}.json.tpl")
# }

# data "aws_iam_policy_document" "b" {
# source_policy_documents = [file("policies/denyRootUser.json"), file("policies/denyIamAccessKeyCreation.json")]
# }


##############################################################################
## This data block will help concat and covert policy data into json format ##
##############################################################################

data "aws_iam_policy_document" "b" {
  for_each                = local.local_policy_list
  source_policy_documents = each.value
}
