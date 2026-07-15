# SQS Queue — Wazuh AWS Logs S3 Event Notifications
#
# Queue: wazuh-aws-logs-notify
# Purpose: Receives S3 event notifications when new log objects are delivered
#          to the central bucket (management-wazuh-aws-logs). The Wazuh Manager
#          aws-s3 wodle consumes this queue instead of polling S3 directly.
#
# Benefits over direct S3 polling:
#   - Lower S3 API costs (no ListBucket calls)
#   - Faster event processing (near real-time)
#   - Better scalability for high-volume log ingestion
#   - Reduced duplicate reads
#
# Dependencies:
#   - Central S3 bucket: management-wazuh-aws-logs
#   - IRSA policy must include sqs:ReceiveMessage, sqs:DeleteMessage, sqs:GetQueueAttributes
#
# S3 Event Configuration:
#   After creating this queue, configure S3 bucket notifications
#   (see ../s3/wazuh-aws-logs-notification/)
#     Event type: s3:ObjectCreated:*
#     Prefix filter: AWSLogs/
#     Destination: This SQS queue ARN

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/sqs/"
}

inputs = {
  name       = "wazuh-aws-logs-notify"
  service    = "wazuh"
  attributes = "aws-logs-notify"

  # --- Queue settings ---
  # Visibility timeout: 5 minutes
  # Must be longer than the Wazuh aws-s3 processing time per batch
  visibility_timeout_seconds = 700

  # Message retention: 1 days (default)
  # If Wazuh Manager is down for >1 days, messages are lost.
  # Increase if needed for maintenance windows.
  message_retention_seconds = 84600

  # Long polling: 20 seconds to reduce empty ReceiveMessage calls
  receive_wait_time_seconds = 20

  # No delay on delivery
  delay_seconds = 0

  # --- Dead Letter Queue ---
  create_dlq        = false
  max_receive_count  = 5

  # --- Server-side encryption (SSE-SQS) ---
  kms_master_key_id                 = ""
  kms_data_key_reuse_period_seconds = 300

  # --- SQS policy: allow only S3 bucket to send notifications ---
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Notifications"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:us-east-2:547580490325:wazuh-aws-logs-notify"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::management-wazuh-aws-logs"
          }
          StringEquals = {
            "aws:SourceAccount" = "547580490325"
          }
        }
      }
    ]
  })

  # --- CloudWatch Alarms ---
  alarm_enabled = false

  # Queue backlog: alert if >500 messages visible (consumer falling behind)
  ApproximateNumberOfMessagesVisible = 500

  # Oldest message age: alert if oldest message is >1 hour old (3600 seconds)
  oldest_message_age_threshold = 3600

  # DLQ: alert if any message lands in DLQ (processing failure)
  dlq_messages_threshold = 1
}
