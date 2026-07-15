# AWS Certificate Manager

This terraform module will helps user to:

- Create AWS Certificate Manager for given domain
- Create AWS Certificate Manager for given domain for CDN specifically
- Create CNAME record in route53

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|AWS region|`string`|-|yes|-|
|aws_assume_role_arn|IAM Role to be used to create resources|`string`|-|no|-|
|namespace|Namespace, which could be your organization name, e.g. 'eg' or 'cp'|`string`|-|no|-|
|stage|Stage, e.g. 'prod', 'staging', 'dev' or 'testing'|`string`|-|no|-|
|certificate_domain_name|Domain name (E.g. staging.salaryse.com)|`string`|-|no|-|
|cdn_acm_enabled|Specify if cdn_acm certificate is required|`bool`|-|yes|-|
|service|Github repo for required resource, empty value will make it gitops repo|`string`|-|no|-|
|attributes|Custom attributes signifying purpose of resource|`string`|-|no|-|
|zone_name|The name of the desired Route53 Hosted Zone|`string`|-|no|-|
|acm_name|The name of the acm certificate name|`string`|-|yes|-|

## Usage

```hcl
attributes              = "acm"
zone_name               = "test.salaryse.com"
certificate_domain_name = "test.salaryse.com"
cdn_acm_enabled         = true
```
