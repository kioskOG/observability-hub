module "label" {
  source    = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.25.0"
  namespace = var.namespace
  stage     = var.stage
  name      = length(split("/", var.service)) == 1 ? var.service : split("/", var.service)[length(split("/", var.service)) - 1]

  tags = {
    Namespace  = var.namespace
    Stage      = var.stage
    Team       = "platform"
    Service    = var.service
    Attributes = var.attributes
  }
}

locals {

}

locals {
  enabled                     = var.enabled
  source_policy_documents     = compact(concat([var.policy], var.source_policy_documents))
  partition                   = join("", data.aws_partition.current.*.partition)
  versioning_enabled          = local.enabled && var.versioning_enabled
  bucket_name                 = var.bucket_name != null && var.bucket_name != "" ? var.bucket_name : "${var.namespace}-${var.stage}-${module.label.name}"
  bucket_arn                  = "arn:${local.partition}:s3:::${join("", aws_s3_bucket.default.*.id)}"
  public_access_block_enabled = var.block_public_acls || var.block_public_policy || var.ignore_public_acls || var.restrict_public_buckets
  acl_grants = var.grants == null ? [] : flatten(
    [
      for g in var.grants : [
        for p in g.permissions : {
          id         = g.id
          type       = g.type
          permission = p
          uri        = g.uri
        }
      ]
  ])
}

data "aws_partition" "current" { count = local.enabled ? 1 : 0 }
data "aws_canonical_user_id" "default" { count = local.enabled ? 1 : 0 }

resource "aws_s3_bucket" "default" {
  count         = local.enabled ? 1 : 0
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(module.label.tags, var.tags)
}
resource "aws_s3_bucket_versioning" "default" {
  count = local.versioning_enabled ? 1 : 0

  bucket = join("", aws_s3_bucket.default.*.id)

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "default" {
  count  = local.enabled && var.logging != null ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  target_bucket = var.logging["bucket_name"]
  target_prefix = var.logging["prefix"]
}


resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  count  = local.enabled && var.kms_master_key_arn != "" ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  rule {
    bucket_key_enabled = var.bucket_key_enabled

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_master_key_arn != "" ? "aws:kms" : var.sse_algorithm
      kms_master_key_id = var.kms_master_key_arn
    }
  }
}

resource "aws_s3_bucket_acl" "default" {
  count  = local.enabled && var.acl_enabled ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  # Conflicts with access_control_policy so this is enabled if no grants
  acl = try(length(local.acl_grants), 0) == 0 ? var.acl : null

  dynamic "access_control_policy" {
    for_each = try(length(local.acl_grants), 0) == 0 || try(length(var.acl), 0) > 0 ? [] : [1]

    content {
      dynamic "grant" {
        for_each = local.acl_grants

        content {
          grantee {
            id   = grant.value.id
            type = grant.value.type
            uri  = grant.value.uri
          }
          permission = grant.value.permission
        }
      }

      owner {
        id = join("", data.aws_canonical_user_id.default.*.id)
      }
    }
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  count = local.enabled ? 1 : 0

  dynamic "statement" {
    for_each = var.allow_encrypted_uploads_only ? [1] : []

    content {
      sid       = "DenyIncorrectEncryptionHeader"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]

      principals {
        identifiers = ["*"]
        type        = "*"
      }

      condition {
        test     = "StringNotEquals"
        values   = [var.sse_algorithm]
        variable = "s3:x-amz-server-side-encryption"
      }
    }
  }

  dynamic "statement" {
    for_each = var.allow_encrypted_uploads_only ? [1] : []

    content {
      sid       = "DenyUnEncryptedObjectUploads"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${local.bucket_arn}/*"]

      principals {
        identifiers = ["*"]
        type        = "*"
      }

      condition {
        test     = "Null"
        values   = ["true"]
        variable = "s3:x-amz-server-side-encryption"
      }
    }
  }

  dynamic "statement" {
    for_each = var.allow_ssl_requests_only ? [1] : []

    content {
      sid       = "ForceSSLOnlyAccess"
      effect    = "Deny"
      actions   = ["s3:*"]
      resources = [local.bucket_arn, "${local.bucket_arn}/*"]

      principals {
        identifiers = ["*"]
        type        = "*"
      }

      condition {
        test     = "Bool"
        values   = ["false"]
        variable = "aws:SecureTransport"
      }
    }
  }

  dynamic "statement" {
    for_each = var.privileged_principal_arns

    content {
      sid     = "AllowPrivilegedPrincipal[${statement.key}]" # add indices to Sid
      actions = var.privileged_principal_actions
      resources = distinct(flatten([
        "arn:${local.partition}:s3:::${join("", aws_s3_bucket.default.*.id)}",
        formatlist("arn:${local.partition}:s3:::${join("", aws_s3_bucket.default.*.id)}/%s*", values(statement.value)[0]),
      ]))
      principals {
        type        = "AWS"
        identifiers = [keys(statement.value)[0]]
      }
    }
  }
}

data "aws_iam_policy_document" "aggregated_policy" {
  count = local.enabled ? 1 : 0

  source_policy_documents   = data.aws_iam_policy_document.bucket_policy.*.json
  override_policy_documents = local.source_policy_documents
}

resource "aws_s3_bucket_policy" "default" {
  count      = local.enabled && (var.allow_ssl_requests_only || var.allow_encrypted_uploads_only || length(var.privileged_principal_arns) > 0 || length(local.source_policy_documents) > 0) ? 1 : 0
  bucket     = join("", aws_s3_bucket.default.*.id)
  policy     = join("", data.aws_iam_policy_document.aggregated_policy.*.json)
  depends_on = [aws_s3_bucket_public_access_block.default]
}

resource "aws_s3_bucket_public_access_block" "default" {
  count  = local.enabled && local.public_access_block_enabled ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}


resource "aws_s3_bucket_website_configuration" "default" {
  count  = local.enabled && (try(length(var.website_inputs), 0) > 0) ? 1 : 0
  bucket = join("", aws_s3_bucket.default[*].id)

  dynamic "index_document" {
    for_each = try(length(var.website_inputs[0].index_document), 0) > 0 ? [true] : []
    content {
      suffix = var.website_inputs[0].index_document
    }
  }

  dynamic "error_document" {
    for_each = try(length(var.website_inputs[0].error_document), 0) > 0 ? [true] : []
    content {
      key = var.website_inputs[0].error_document
    }
  }

  dynamic "routing_rule" {
    for_each = try(length(var.website_inputs[0].routing_rules), 0) > 0 ? var.website_inputs[0].routing_rules : []
    content {
      dynamic "condition" {
        // Test for null or empty strings
        for_each = try(length(routing_rule.value.condition.http_error_code_returned_equals), 0) + try(length(routing_rule.value.condition.key_prefix_equals), 0) > 0 ? [true] : []
        content {
          http_error_code_returned_equals = routing_rule.value.condition.http_error_code_returned_equals
          key_prefix_equals               = routing_rule.value.condition.key_prefix_equals
        }
      }

      redirect {
        host_name               = routing_rule.value.redirect.host_name
        http_redirect_code      = routing_rule.value.redirect.http_redirect_code
        protocol                = routing_rule.value.redirect.protocol
        replace_key_prefix_with = routing_rule.value.redirect.replace_key_prefix_with
        replace_key_with        = routing_rule.value.redirect.replace_key_with
      }
    }
  }
}
