resource "aws_wafv2_web_acl_logging_configuration" "default" {
  count                   = var.create_logging_configuration ? 1 : 0
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.logs_stream[0].arn]
  resource_arn            = aws_wafv2_web_acl.main.arn

  dynamic "redacted_fields" {
    for_each = [var.redacted_fields]

    content {
      dynamic "method" {
        for_each = redacted_fields.value.method_enabled ? [1] : []

        content {
        }
      }

      dynamic "query_string" {
        for_each = redacted_fields.value.query_string_enabled ? [1] : []

        content {
        }
      }

      dynamic "uri_path" {
        for_each = redacted_fields.value.uri_path_enabled ? [1] : []

        content {
        }
      }

      dynamic "single_header" {
        for_each = lookup(redacted_fields.value, "single_header", null) != null ? toset(redacted_fields.value.single_header) : []
        content {
          name = single_header.value
        }
      }
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "logs_stream" {
  count       = var.create_logging_configuration ? 1 : 0
  name        = var.firehose_name == "" ? "aws-waf-logs-${var.stage}" : var.firehose_name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.waf_log_stream_role[0].arn
    bucket_arn         = var.s3_bucket_arn
    buffer_size        = 2
    buffer_interval    = 60
    prefix             = "AWSLogs/${var.account_id}/waf/"
    compression_format = "GZIP"

  }
}


resource "aws_iam_role" "waf_log_stream_role" {
  count = var.create_logging_configuration ? 1 : 0
  name  = "waf-log-stream-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "custom-policy" {
  count  = var.create_logging_configuration ? 1 : 0
  name   = "waf_logs-role-custom-policy"
  role   = aws_iam_role.waf_log_stream_role[0].id
  policy = data.template_file.waf_logs_policy.rendered
}

data "template_file" "waf_logs_policy" {
  template = file("${path.module}/fileupload-policy.json.tpl")
  vars = {
    s3_bucket_arn = "${var.s3_bucket_arn}"
    firehose_name = var.firehose_name == "" ? "aws-waf-logs-${var.stage}" : var.firehose_name
    region        = local.region
    account_id    = "${var.account_id}"
    kms_id        = "${var.kms_id}"
  }
}