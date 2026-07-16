resource "aws_security_group" "this" {
  for_each               = var.security_groups
  name                   = "${each.value.stage}-${each.value.name}"
  description            = each.value.description
  vpc_id                 = each.value.vpc_id
  revoke_rules_on_delete = try(each.value.revoke_rules_on_delete, true)

  tags = merge(
    {
      "Name" = each.value.name
    },
    each.value.tags
  )

  timeouts {
    create = try(each.value.create_timeout, "10m")
    delete = try(each.value.delete_timeout, "10m")
  }
}


locals {
  flat_ingress_rules = {
    for pair in flatten([
      for sg_key, sg in var.security_groups : [
        for rule_key, rule in try(sg.custom_ingress_rules, {}) : {
          key = "${sg_key}-${rule_key}"
          value = {
            rule  = rule
            sg_id = aws_security_group.this[sg_key].id
          }
        }
      ]
    ]) : pair.key => pair.value
  }

  flat_egress_rules = {
    for pair in flatten([
      for sg_key, sg in var.security_groups : [
        for rule_key, rule in try(sg.custom_egress_rules, {}) : {
          key = "${sg_key}-${rule_key}"
          value = {
            rule  = rule
            sg_id = aws_security_group.this[sg_key].id
          }
        }
      ]
    ]) : pair.key => pair.value
  }
}



resource "aws_security_group_rule" "custom_ingress_rules" {
  for_each = local.flat_ingress_rules

  type                     = each.value.rule.type
  from_port                = each.value.rule.port
  to_port                  = each.value.rule.port
  protocol                 = each.value.rule.protocol
  description              = each.value.rule.description
  security_group_id        = each.value.sg_id
  self                     = lookup(each.value.rule, "self", null)
  source_security_group_id = lookup(each.value.rule, "source_security_group_id", null)
  cidr_blocks              = lookup(each.value.rule, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value.rule, "ipv6_cidr_blocks", null)
}

resource "aws_security_group_rule" "custom_egress_rules" {
  for_each = local.flat_egress_rules

  type                     = each.value.rule.type
  from_port                = each.value.rule.port
  to_port                  = each.value.rule.port
  protocol                 = each.value.rule.protocol
  description              = each.value.rule.description
  security_group_id        = each.value.sg_id
  self                     = lookup(each.value.rule, "self", null)
  source_security_group_id = lookup(each.value.rule, "source_security_group_id", null)
  cidr_blocks              = lookup(each.value.rule, "cidr_blocks", null)
  ipv6_cidr_blocks         = lookup(each.value.rule, "ipv6_cidr_blocks", null)
}
