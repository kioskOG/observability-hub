# AWS ECR

This terraform module will helps user to:

- Create ECR repository in loop
- Put ECR policy to ECR Repo
- Enable life cycle on ECR Repository

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|Region specified for AWS Services |`string`|-|yes|-|
|namespace|Namespace, which could be your organization name or abbreviation, e.g. 'eg' or 'cp'|`string`|-|no|-|
|stage|Stage, e.g. 'prod', 'staging', 'dev', OR 'source', 'build', 'test', 'deploy', 'release'|`string`|-|no|-|
|name|ECR Repository Name, e.g. 'test-app-dev' or 'test-app-prod'|`string`|-|yes|-|
|repositories|Required repository names in list|`any`|-|no|-|
|service|Service name identifier, like Name or Github repository|`string`|-|no|-|
|attributes|Custom attributes signifying purpose of resource|`string`|-|no|-|
|image_scaning_enable|Custome value to enable scaning on AWS ECR|`bool`|1|no|-|
|enable_expiry|Lifecycle policy for expiry|`bool`|1|no|-|
|scanning_rules|Scanning rule for ECR|`any`|-|no|-|

## Usage

```hcl
 service    = path_relative_to_include()
  attributes = "application-repositories"
  trusted_roles_ecr = [
    "arn:aws:iam::1234567890:root"
  ]
  enable_expiry        = true
  image_scaning_enable = true
  repositories = [
    "test-app-dev"
    "test-app-prod"
  ]
```
