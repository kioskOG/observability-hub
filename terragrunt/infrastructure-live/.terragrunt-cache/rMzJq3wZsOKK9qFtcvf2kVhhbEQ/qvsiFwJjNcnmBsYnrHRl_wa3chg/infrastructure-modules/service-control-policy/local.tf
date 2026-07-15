######################################################################
## This local variable will create a custom local variable which is ##
## required for aws_organizations_policy_attachment resource block  ##
## Input Variable:                                                  ##
##                                                                  ##
##   attachement_information = {                                    ##
##       "XXXXXXXXXXXY" = [                                         ##
##           "commonDenyPolicy",                                    ##
##       ],                                                         ##
##       "XXXXXXXXXXXX" = [                                         ##
##           "commonDenyPolicy",                                    ##
##       ],                                                         ##
##   }                                                              ##
## Resultant variable:                                              ##
##                                                                  ##
##  XXXXXXXXXXXY@commonDenyPolicy                                   ##
##  XXXXXXXXXXXX@commonDenyPolicy                                   ##
##                                                                  ##
######################################################################

locals {
  attchement_var = flatten([
    for account_id, policy_name_list in var.attachement_information : [
      for policy_name in policy_name_list :
      "${account_id}@${policy_name}"
    ]
    ]
  )


  ###################################################################
  ## This local variable will create a custom local variable which ##
  ## is required for aws_organizations_policy resource block       ##
  ##                                                               ##
  ##                                                               ##
  ##   attachement_information = {                                 ##
  ##                                                               ##
  #   organizations_policy_name = {                                ##
  #       "commonDenyPolicy" = [                                   ##
  #               "denyRootUser",                                  ##
  #               "denyLeaveOrganization",                         ##
  #       ],                                                       ##
  #       "userDenyPolicy" = [                                     ##
  #               "denyRootUser",                                  ##
  #       ],                                                       ##
  #   }                                                            ##
  ##                                                               ##
  ## Resultant variable:                                           ##
  ##                                                               ##
  # # {                                                            ##
  ##   "userDenyPolicy" = [                                        ##
  ##     <<-EOT                                                    ##
  ##     {                                                         ##
  ##       "Version": "2012-10-17",                                ##
  ##       "Statement": [                                          ##
  ##         ##                                                    ##
  ##       ]                                                       ##
  ##     }                                                         ##
  ##     EOT,                                                      ##
  ##   ]                                                           ##
  ##   "commonDenyPolicy" = [                                      ##
  ##     <<-EOT                                                    ##
  ##     {                                                         ##
  ##       "Version": "2012-10-17",                                ##
  ##       "Statement": [                                          ##
  ##         ##                                                    ##
  ##       ]                                                       ##
  ##     }                                                         ##
  ##     EOT,                                                      ##
  ##     <<-EOT                                                    ##
  ##     {                                                         ##
  ##       "Version": "2012-10-17",                                ##
  ##       "Statement": [                                          ##
  ##         ##                                                    ##
  ##       ]                                                       ##
  ##     }                                                         ##
  ##     EOT,                                                      ##
  ##   ]                                                           ##
  ## }                                                             ##
  ##                                                               ##
  ###################################################################

  local_policy_list = {
    for root_policy_name, sub_policy_list in var.organizations_policy_name :
    "${root_policy_name}" => [
      for sub_policy in sub_policy_list :
      file("policies/${sub_policy}.json")
    ]
  }
}
