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
#   After creating this queue, configure S3 bucket notifications:
#     Event type: s3:ObjectCreated:*
#     Prefix filter: AWSLogs/
#     Destination: This SQS queue ARN

include {
  path = find_in_parent_folders()
}

# TODO: Replace with actual SQS module source from infrastructure-modules
# terraform {
#   source = "../../../../../..//infrastructure-modules/sqs/"
# }

# inputs = {
#   queue_name = "wazuh-aws-logs-notify"
#
#   # Message retention: 4 days (default)
#   # If Wazuh Manager is down for >4 days, messages are lost.
#   # Increase if needed for maintenance windows.
#   message_retention_seconds = 345600
#
#   # Visibility timeout: 5 minutes
#   # Must be longer than the Wazuh aws-s3 processing interval (10m default)
#   visibility_timeout_seconds = 300
#
#   # Dead letter queue for failed processing
#   # redrive_policy = {
#   #   deadLetterTargetArn = "<DLQ_ARN>"
#   #   maxReceiveCount     = 5
#   # }
#
#   # SQS policy allowing S3 bucket to send notifications
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "AllowS3Notifications"
#         Effect    = "Allow"
#         Principal = {
#           Service = "s3.amazonaws.com"
#         }
#         Action   = "sqs:SendMessage"
#         Resource = "arn:aws:sqs:us-east-2:000000000001:wazuh-aws-logs-notify"
#         Condition = {
#           ArnLike = {
#             "aws:SourceArn" = "arn:aws:s3:::management-wazuh-aws-logs"
#           }
#           StringEquals = {
#             "aws:SourceAccount" = "000000000001"
#           }
#         }
#       }
#     ]
#   })
#
#   # Server-side encryption
#   sqs_managed_sse_enabled = true
#
#   tags = {
#     Service   = "wazuh"
#     Component = "aws-logs-notify"
#     ManagedBy = "Terraform"
#   }
# }
