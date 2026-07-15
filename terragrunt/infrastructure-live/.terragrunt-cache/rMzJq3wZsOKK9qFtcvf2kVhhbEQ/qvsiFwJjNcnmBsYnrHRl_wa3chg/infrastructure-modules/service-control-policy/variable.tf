########################################################
## Variable block to get region information from user ##
########################################################

variable "region" {
  type        = string
  description = "AWS region"
}

#############################################################################
## Variable block to get policy name and their value information from user ##
#############################################################################

variable "organizations_policy_name" {
  type    = any
  default = {}
}

##############################################################################
## Variable block to get policy attachment information to account from user ##
##############################################################################

variable "attachement_information" {
  type    = any
  default = {}
}
