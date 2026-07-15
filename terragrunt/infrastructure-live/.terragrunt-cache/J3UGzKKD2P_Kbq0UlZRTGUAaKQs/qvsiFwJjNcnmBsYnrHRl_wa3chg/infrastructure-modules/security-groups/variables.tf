variable "security_groups" {
  description = "Map of security group definitions including their rules"
  type = map(object({
    name        = string
    description = string
    stage       = string
    vpc_id      = string
    tags        = map(string)
    custom_ingress_rules = optional(map(object({
      description              = string
      type                     = string
      port                     = number
      protocol                 = string
      self                     = optional(bool)
      source_security_group_id = optional(string)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
    })))
    custom_egress_rules = optional(map(object({
      description              = string
      type                     = string
      port                     = number
      protocol                 = string
      self                     = optional(bool)
      source_security_group_id = optional(string)
      cidr_blocks              = optional(list(string))
      ipv6_cidr_blocks         = optional(list(string))
    })))
    revoke_rules_on_delete = optional(bool)
    create_timeout         = optional(string)
    delete_timeout         = optional(string)
  }))
}

variable "region" {
  description = "AWS region to deploy security groups"
  type        = string
  default     = ""
}
