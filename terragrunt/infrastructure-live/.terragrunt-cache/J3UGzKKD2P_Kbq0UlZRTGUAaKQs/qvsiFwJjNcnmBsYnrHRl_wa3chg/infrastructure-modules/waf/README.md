# AWS WAF

This terraform module helps user to:

- Create WAF for CDN.
- Shipping WAF logs to `<bucket-name>` S3 bucket via kinesis data stream.

```text
NOTE: Priority 0-25 is fixed for Managed Rules.
```

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|Region specified for AWS Services |`string`|-|no|-|
|name|A name of the WebACL|`string`|-|yes|-|
|description|Description for WEB Acl|string|-|no|-|
|scope|The scope of this Web ACL. Valid options: CLOUDFRONT, REGIONAL|`string`|-|yes|-|
|allow_default_action|Set to `true` for WAF to allow requests by default. Set to `false` for WAF to block requests by default|`bool`|true|yes|-|
|visibility_config|Visibility config for WAFv2 web acl|`map(string)`|{}|no|-|
|firehose_name|Name for the firehose delivery stream|`string`|-|no|-|
|hostname_path_based_statement_rules|Hostname path based custome rules to be created for WAF|`any`|[]|no|-|
|redacted_fields|Parts of the request that you want to keep out of the logs|`any`|`{method_enabled = false, query_string_enabled = false,uri_path_enabled = false}`|no|-|
|tags|A mapping of tags to assign to the WAFv2 ACL|`map(string)`|{}|no|-|
|ip_rate_url_based_rules|Rate based rules for WAF|`any`|[]|no|-|
|create_logging_configuration|Whether to create logging configuration in order start logging from a WAFv2 Web ACL to Amazon Kinesis Data Firehose|`bool`|false|no|-|
|stage|stage name, Ex - salaryse-dev|`string`|-|-|-|
|account_id|Account ID in which WAF is created|`string`|-|yes|-|
|ip_set_addresses|IPv4 addresses for IP sets|`any`|{}|yes|-|
|hostname_ip_set_statement_rules|Hostname IP set based custome rules to be created for WAF|`any`|[]|no|ip_set_addresses|
|hostname_path_ip_set_statement_rules|Hostname & path based IP set custome rules to be created for WAF|`any`|[]|-|ip_set_addresses|
|rule_group_name|Rule Group name|`string`|custom-rule-group|-|-|
|rule_groups_capacity|Rule Groups Capacity|`number`|2|-|rule_group_name|
|rule_group_priority|Rule Group priority|`number`|26|-|-|

## Usage

```hcl
  name                         = "tset-dev-web-acl"
  allow_default_action         = false
  scope                        = "CLOUDFRONT"
  create_logging_configuration = true
  rule_groups_capacity         = 100
  rule_group_priority          = 26
  ip_set_addresses = {
    "vpn" = {
      description = "vpn"
      addresses = ["x.x.x.x/32"]
    }
  }
  hostname_based_everywhere_rules = [{
      name                  = "test-application-rules"
      host                  = [
        "example.com",
        "example1.com"
        ]
      priority              = 10
      positional_constraint = "EXACTLY"
      single_header         = "host"
    }]
  hostname_path_based_statement_rules = [
    {
      name                  = "test-application-rules"
      host                  = "example.com"
      priority              = 30
      positional_constraint = "EXACTLY"
      single_header         = "host"
      or_statement = [
        "/test-application",
        "/test-application-2"

      ]
    }
  ]
  # hostname_ip_set_statement_rules = [
  #   {
  #     name                  = "test-application-ipset-hostname-rules"
  #     priority              = 27
  #     positional_constraint = "EXACTLY"
  #     host                  = "example.com"
  #     ip_set_name           = "test"
  #   }
  # ]
  hostname_path_ip_set_statement_rules = [
    {
      name                  = "test-application-ipset-hostname-path-rules"
      priority              = 26
      positional_constraint = "EXACTLY"
      host                  = "example.com"
      ip_set_name           = "vpn"
      or_statement = [
        "/test-app",
        "/403"              // So that OR statement would work.
      ]
    }
  ]
```