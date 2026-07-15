locals {

  region = var.scope == "CLOUDFRONT" ? "us-east-1" : var.region
  managed_rules = [
    {
      name            = "AWSManagedRulesAmazonIpReputationList",
      priority        = "0"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesAmazonIpReputationList"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesAnonymousIpList"
      priority        = "1"
      override_action = "none"
      excluded_rules  = ["HostingProviderIPList"]
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesAnonymousIpList"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesKnownBadInputsRuleSet"
      priority        = "2"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesPHPRuleSet"
      priority        = "3"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesPHPRuleSet"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      priority        = "4"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesSQLiRuleSet"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesWordPressRuleSet"
      priority        = "5"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesWordPressRuleSet"
        sampled_requests_enabled   = true
      }
    },
    {
      name            = "AWSManagedRulesLinuxRuleSet"
      priority        = "6"
      override_action = "none"
      excluded_rules  = []
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "AWSManagedRulesLinuxRuleSet"
        sampled_requests_enabled   = true
      }
    }
  ]
}