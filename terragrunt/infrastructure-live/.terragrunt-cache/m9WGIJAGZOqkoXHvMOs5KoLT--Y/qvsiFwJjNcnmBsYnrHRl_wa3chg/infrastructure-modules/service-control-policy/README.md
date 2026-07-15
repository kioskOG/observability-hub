# AWS Service Control Policy

This terraform module will help user to:

- Setup organization policy
- Attach Policy to specific account

## Variable definition

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|organizations_policy_name|SCP Policy name that needs to configure|list|`[]`|no|-|
|attachement_information|Account/Policy relation|any|`{}`|no|organizations_policy_name|
|region|-|`string`|-|yes|-|

## How To

```txt
organizations_policy_name = [
    "commonpolicy" = [
        "denyRootUser",
        "denyLeaveOrganization"
        ],
    "denypolicy" = [
        "denyRootUser",
        "denyLeaveOrganization"
        ]
]

attachement_information = {
    "123456789" = [
        "commonpolicy",
        "denypolicy"
    ],
    "987654321" = [
        "commonpolicy"
    ]
}
```

## Template location

When we define `organizations_policy_name` and mention policy name in list. At the same, we also need to define tpl file under `templates/` present in module.

Example:

```txt
organizations_policy_name = [
        "test",
]
```

templates file:

```txt
test.json.tpl
```

## TODO

|Issues|JIRA|Status|priority|Maintainer|Comment|
|-|-|-|-|-|-|
|Policy attachment to OUs|-|PENDING|Low|Bhupender Singh|-|
|AWS SCP policy setup to deny deletion of AMI/Snapshots|[SQ-230](https://nomupay.atlassian.net/browse/SQ-230)|PENDING|MEDIUM|Bhupender Singh|-|
