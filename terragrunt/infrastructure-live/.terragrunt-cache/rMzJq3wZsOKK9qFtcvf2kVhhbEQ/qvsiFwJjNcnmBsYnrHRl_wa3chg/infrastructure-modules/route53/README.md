# AWS Route53

This terraform module helps user to:

- Create private zone in route53
- Create public zone in route53
- Enable loggng for Route53 zone
- Create cloudwatch log for logging

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|AWS region|`string`|-|yes|-|
|aws_assume_role_arn|IAM Role to be used to create resources|`string`|-|no|-|
|namespace|Namespace, which could be your organization name, e.g. 'eg' or 'cp'|`string`|-|no|-|
|stage|Stage, e.g. 'prod', 'staging', 'dev' or 'testing'|`string`|-|no|-|
|parent_domain_name|Parent domain name (E.g. salaryse.com)|`string`|-|yes|-|
|expose_parent|will create parent domain (E.g. salaryse.com)|`bool`|false|yes|-|
|service|Github repo for required resource, empty value will make it gitops repo|`string`|-|no|-|
|attributes|Custom attributes signifying purpose of resource|`string`|-|no|-|
|create_account_zone|If zone to be created in this account or not|`bool`|true|no|-|
|create_route_log_group|Spcifiy if cloudwatch log group to be created for parent domain|`bool`|false|no|-|
|zone_name|Specify the zone name you want to create|`string`|-|no|-|
|enable_logging|Whether to enable query_log|`bool`|false|no|-|
|s3_bucker_arn|If provided will setup a log subscription using firehose to deliver the logs|`string`|-|no|-|
|vpc_id|IVPC where supporting zone are to be mapped|`string`|-|yes|-|
|internal_zone_enable|Enable internal zone in Route53|`bool`|false|no|-|
|internal_zone_name|"Specify the internal zone name you want to create|`string`|-|no|-|

## Usage

```hcl
attributes           = "infra"
expose_parent        = false
zone_name            = "test.salaryse.com"
stage                = "dev" // The zone would be test.salaryse.com
internal_zone_enable = false
```