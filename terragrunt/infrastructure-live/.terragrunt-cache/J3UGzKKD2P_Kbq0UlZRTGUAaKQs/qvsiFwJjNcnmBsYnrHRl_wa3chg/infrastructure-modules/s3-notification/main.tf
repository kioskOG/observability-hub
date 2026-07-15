# S3 Bucket Notification → SQS
#
# This module configures S3 event notifications to forward object creation
# events to an SQS queue. It is intentionally kept separate from the main
# S3 module to avoid modifying the general-purpose bucket module and to
# allow independent lifecycle management.
#
# Usage: Deploy AFTER both the S3 bucket and SQS queue exist.

resource "aws_s3_bucket_notification" "this" {
  bucket = var.bucket_id

  queue {
    queue_arn     = var.sqs_queue_arn
    events        = var.events
    filter_prefix = var.filter_prefix
    filter_suffix = var.filter_suffix
  }
}
