# AWS IAM User & Group Module

This terraform module is help user to

- Create AWS IAM User [Associated with same name group]
- Create AWS Group
- Attach AWS IAM Managed Policy to AWS IAM User
- Attach AWS IAM Managed Policy to AWS IAM Role
- Create custom policy for AWS IAM User
- Create custom policy for AWS IAM Role
- Trusted Entity support for AWS IAM Role
- Attach AWS IAM Custom policy to AWS IAM User
- Attach AWS IAM Custom policy to AWS IAM Role

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|Region where resources will configured|`string`|-|yes|-|
|iam_user|-|`any`|`{}`|no|-|
|iam_role|-|`any`|`{}`|no|-|
|oidc|Whether to create OIDC or not|`any`|`{}`|no|-|
|additional_tags|-|`map(any)`|`default = { "ManagedBy" = "Terraform" }`|no|-|

## Usage

```hcl
iam_user = {
  "user1" = {
    custom_policy = [
      "denyS3Public"
    ],
    managed_policy = [
      "AWSHealthFullAccess",
      "AmazonRDSFullAccess"
    ]
  },
  "user2" = {
    custom_policy = [
      "denyS3NonEncryptContent"
    ]
    managed_policy = [
      "AWSHealthFullAccess"
    ]
  }
}
iam_role = {
  "role1" = {
    custom_policy = [
      "denyS3Public"
    ],
    managed_policy = [
      "AWSHealthFullAccess",
      "AmazonRDSFullAccess"
    ]
  },
  "role2" = {
    custom_policy = [
      "denyS3NonEncryptContent"
    ]
    managed_policy = [
      "AWSHealthFullAccess"
    ]
  }
}

oidc = {
  "oidc1" = {
    url                     = "https://xxxxx.xxxxxx.com"
    client_id_list          = ["sts.amazonaws.com"]
    custom_oidc_thumbprints = []
  }
  "oidc1" = {
    url                     = "https://xxxxx.xxxxxx.com"
    client_id_list          = ["sts.amazonaws.com"]
    custom_oidc_thumbprints = []
  }
}
```