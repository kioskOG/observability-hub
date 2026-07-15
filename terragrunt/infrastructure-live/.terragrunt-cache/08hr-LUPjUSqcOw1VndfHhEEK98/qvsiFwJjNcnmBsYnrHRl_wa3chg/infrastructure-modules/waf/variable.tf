variable "region" {
  type        = string
  description = "Provides details about a specific AWS region"
  default     = ""
}

variable "name" {
  type        = string
  description = "A name of the WebACL."
}

variable "description" {
  type        = string
  description = "Description for WEB Acl"
  default     = ""

}
variable "scope" {
  type        = string
  description = "The scope of this Web ACL. Valid options: CLOUDFRONT, REGIONAL."
}

variable "allow_default_action" {
  type        = bool
  description = "Set to `true` for WAF to allow requests by default. Set to `false` for WAF to block requests by default."
  default     = true
}

variable "visibility_config" {
  description = "Visibility config for WAFv2 web acl"
  type        = map(string)
  default     = {}
}

variable "firehose_name" {
  description = "Name for the firehose delivery stream"
  type        = string
  default     = ""
}

variable "kms_id" {
  description = "KMS id for s3 bucket"
  type        = string
  default     = ""
}

variable "s3_bucket_arn" {
  description = "S3 bucket arn for waf logging"
  type        = string
  default     = ""
}

variable "hostname_path_based_statement_rules" {
  description = "Hostname path based custome rules to be created for WAF"
  type        = any
  default     = []
}

variable "hostname_path_based_statement_block_rules" {
  description = "Hostname path based custome block rules to be created for WAF"
  type        = any
  default     = []
}

variable "hostname_based_everywhere_rules" {
  description = "Hostname based everywhere custome rules to be created for WAF"
  type        = any
  default     = []
}

variable "hostname_path_based_statement_with_whitelisted_ips_rules" {
  description = "Hostname and path based rule with whitelisted ips"
  type        = any
  default     = []
}

variable "redacted_fields" {
  description = "Parts of the request that you want to keep out of the logs"
  type        = any
  default = {
    method_enabled       = false
    query_string_enabled = false
    uri_path_enabled     = false
  }
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the WAFv2 ACL."
  default     = {}
}

variable "ip_rate_url_based_rules" {
  description = "Rate based rules for WAF"
  type        = any
  default     = []
}

variable "create_logging_configuration" {
  type        = bool
  description = "Whether to create logging configuration in order start logging from a WAFv2 Web ACL to Amazon Kinesis Data Firehose."
  default     = false
}

variable "stage" {
  type        = string
  description = "stage name, Ex - solanteq-dev"
  default     = ""
}

variable "account_id" {
  type        = string
  description = "Account ID in which WAF is created"
  default     = ""
}

variable "ip_set_addresses" {
  type        = any
  description = "IPv4 addresses for IP sets"
  default     = {}
}

variable "hostname_ip_set_statement_rules" {
  description = "Hostname IP set based custome rules to be created for WAF"
  type        = any
  default     = []
}

variable "hostname_path_ip_set_statement_rules" {
  description = "Hostname & path based IP set custome rules to be created for WAF"
  type        = any
  default     = []
}

variable "rule_group_name" {
  description = "Rule Group name"
  type        = string
  default     = "custom-rule-group"
}

variable "rule_groups_capacity" {
  description = "Rule Groups Capacity"
  type        = number
  default     = 2
}

variable "rule_group_priority" {
  description = "Rule Group priority"
  type        = number
  default     = 26
}