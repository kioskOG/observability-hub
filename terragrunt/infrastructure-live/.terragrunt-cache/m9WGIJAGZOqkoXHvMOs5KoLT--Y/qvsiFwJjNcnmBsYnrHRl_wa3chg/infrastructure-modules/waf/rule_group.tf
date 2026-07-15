resource "aws_wafv2_rule_group" "example" {
  name     = var.rule_group_name
  scope    = var.scope
  capacity = var.rule_groups_capacity

  ##########################################################
  ######### Hostname based everywere Custom Rules ##########
  ##########################################################

  dynamic "rule" {
    for_each = var.hostname_based_everywhere_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        allow {}
      }

      statement {
        or_statement {
          dynamic "statement" {
            for_each = toset(rule.value.host)
            content {
              byte_match_statement {
                positional_constraint = rule.value.host_positional_constraint
                search_string         = statement.value

                field_to_match {

                  single_header {
                    name = "host"
                  }
                }

                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }


  ################################################################
  ######### Hostname Path Based Custom Rules with IP set - BLOCK ##
  ################################################################
  dynamic "rule" {
    for_each = var.hostname_path_based_statement_with_whitelisted_ips_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        and_statement {
          statement {

            byte_match_statement {
              positional_constraint = rule.value.host_positional_constraint
              search_string         = rule.value.host

              field_to_match {

                single_header {
                  name = "host"
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
          statement {

            or_statement {
              dynamic "statement" {
                for_each = toset(rule.value.or_statement)
                content {
                  byte_match_statement {
                    positional_constraint = try(rule.value.uri_positional_constraint, "STARTS_WITH")
                    search_string         = statement.value
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
          statement {
            not_statement {
              statement {
                ip_set_reference_statement {
                  arn = aws_wafv2_ip_set.ip_set[rule.value.ip_set_name].arn
                }
              }
            }
          }

        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }


  #####################################################
  ######### Hostname Path Based Custom Rules - BLOCK ##
  #####################################################
  dynamic "rule" {
    for_each = var.hostname_path_based_statement_block_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        and_statement {
          statement {

            byte_match_statement {
              positional_constraint = rule.value.host_positional_constraint
              search_string         = rule.value.host

              field_to_match {

                single_header {
                  name = "host"
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
          statement {

            or_statement {
              dynamic "statement" {
                for_each = toset(rule.value.or_statement)
                content {
                  byte_match_statement {
                    positional_constraint = try(rule.value.uri_positional_constraint, "STARTS_WITH")
                    search_string         = statement.value
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  #####################################################
  ######### Hostname Path Based Custom Rules - ALLOW ##
  #####################################################
  dynamic "rule" {
    for_each = var.hostname_path_based_statement_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {

            byte_match_statement {
              positional_constraint = rule.value.host_positional_constraint
              search_string         = rule.value.host

              field_to_match {

                single_header {
                  name = "host"
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
          statement {

            or_statement {
              dynamic "statement" {
                for_each = toset(rule.value.or_statement)
                content {
                  byte_match_statement {
                    positional_constraint = try(rule.value.uri_positional_constraint, "STARTS_WITH")
                    search_string         = statement.value
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  #####################################################
  ######## Hostname IP Set Based Custom Rules #########
  #####################################################
  dynamic "rule" {
    for_each = var.hostname_ip_set_statement_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {

            byte_match_statement {
              positional_constraint = rule.value.host_positional_constraint
              search_string         = rule.value.host

              field_to_match {

                single_header {
                  name = "host"
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.ip_set[rule.value.ip_set_name].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  #####################################################
  ## Hostname & Path with IP Set Based Custom Rules ###
  #####################################################
  dynamic "rule" {
    for_each = var.hostname_path_ip_set_statement_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {

            byte_match_statement {
              positional_constraint = rule.value.host_positional_constraint
              search_string         = rule.value.host

              field_to_match {

                single_header {
                  name = "host"
                }
              }

              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.ip_set[rule.value.ip_set_name].arn
            }
          }
          statement {
            or_statement {
              dynamic "statement" {
                for_each = toset(rule.value.or_statement)
                content {
                  byte_match_statement {
                    positional_constraint = try(rule.value.uri_positional_constraint, "STARTS_WITH")
                    search_string         = statement.value
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.rule_group_name
    sampled_requests_enabled   = true
  }
}