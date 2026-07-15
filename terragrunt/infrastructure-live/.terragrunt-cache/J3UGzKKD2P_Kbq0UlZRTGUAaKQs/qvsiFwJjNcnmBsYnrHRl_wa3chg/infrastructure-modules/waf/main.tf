resource "aws_wafv2_web_acl" "main" {
  depends_on = [
    aws_wafv2_ip_set.ip_set
  ]
  name        = var.name
  description = var.description != "" ? var.description : "WAFv2 ACL for ${var.name}"

  scope = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.allow_default_action ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.allow_default_action ? [] : [1]
      content {}
    }
  }

  dynamic "visibility_config" {
    for_each = [var.visibility_config]
    content {
      cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
      sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
      metric_name                = lookup(visibility_config.value, "metric_name", "${var.name}-default-web-acl-metric-name")
    }
  }

  #####################################################
  ################### Rule Group ######################
  #####################################################

  rule {
    name     = var.rule_group_name
    priority = var.rule_group_priority

    override_action {
      none {}
    }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.example.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-${var.rule_group_name}-metric"
      sampled_requests_enabled   = true
    }
  }

  #####################################################
  ################## Managed Rules ####################
  #####################################################

  dynamic "rule" {
    for_each = local.managed_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = "AWS"

          dynamic "excluded_rule" {
            for_each = rule.value.excluded_rules
            content {
              name = excluded_rule.value
            }
          }
        }
      }

      dynamic "visibility_config" {
        for_each = lookup(rule.value, "visibility_config", null) != null ? [rule.value.visibility_config] : []

        content {
          cloudwatch_metrics_enabled = lookup(visibility_config.value, "cloudwatch_metrics_enabled", true)
          metric_name                = visibility_config.value.metric_name
          sampled_requests_enabled   = lookup(visibility_config.value, "sampled_requests_enabled", true)
        }
      }

    }
  }




  tags = var.tags
}
