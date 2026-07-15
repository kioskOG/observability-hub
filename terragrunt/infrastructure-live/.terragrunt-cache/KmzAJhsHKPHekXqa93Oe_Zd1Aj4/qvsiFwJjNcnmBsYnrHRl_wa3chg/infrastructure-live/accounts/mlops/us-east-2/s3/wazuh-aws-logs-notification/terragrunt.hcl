# S3 Bucket Notification → SQS Queue
#
# Purpose: Configures S3 event notifications on the central AWS logs bucket
#          to forward s3:ObjectCreated:* events to the Wazuh SQS ingest queue.
#
# Deploy order:
#   1. S3 bucket (management-wazuh-aws-logs)
#   2. SQS queue (wazuh-aws-logs-notify)
#   3. This notification configuration
#
# Dependencies:
#   - S3 bucket: ../management-wazuh-aws-logs/
#   - SQS queue: ../../sqs/wazuh-aws-logs-notify/

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/s3-notification/"
}

inputs = {
  bucket_id     = "management-wazuh-aws-logs"
  sqs_queue_arn = "arn:aws:sqs:us-east-2:547580490325:wazuh-aws-logs-notify"
  events        = ["s3:ObjectCreated:*"]
  filter_prefix = "AWSLogs/"
}
