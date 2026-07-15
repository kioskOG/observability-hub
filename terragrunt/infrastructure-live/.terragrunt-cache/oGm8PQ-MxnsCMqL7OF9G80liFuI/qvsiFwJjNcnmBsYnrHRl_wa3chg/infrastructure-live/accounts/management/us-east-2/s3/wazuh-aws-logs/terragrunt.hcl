# S3 Bucket — Central AWS Security Logs
#
# Bucket: management-wazuh-aws-logs
# Purpose: Central bucket where ALL 4 accounts deliver their AWS security logs.
#          The Wazuh Manager aws-s3 wodle reads from this bucket via IRSA.
#
# Expected structure:
#   management-wazuh-aws-logs/
#   └── AWSLogs/
#       ├── 000000000001/   (management)
#       │   ├── CloudTrail/
#       │   ├── Config/
#       │   └── GuardDuty/
#       ├── 000000000002/   (dev)
#       │   ├── CloudTrail/
#       │   └── GuardDuty/
#       ├── 000000000003/   (prod)
#       │   ├── CloudTrail/
#       │   ├── Config/
#       │   ├── GuardDuty/
#       │   ├── VPCFlowLogs/
#       │   └── WAF/
#       └── 000000000004/   (audit)
#           ├── CloudTrail/
#           └── GuardDuty/
#
# Encryption: SSE-KMS (AWS managed key)
# Lifecycle:
#   - Standard → Intelligent Tiering at 90 days
#   - Expire at 365 days (raw logs; Wazuh Indexer retains processed alerts)
#
# Bucket Policy: Allows CloudTrail, Config, GuardDuty, and VPC Flow Logs
#                delivery from all 4 accounts (see bucket-policy.json).
#
# SQS Notifications: S3 event notifications → SQS queue for Wazuh consumption
#                    (see ../wazuh-aws-logs-notification/)
#
# Dependencies:
#   - IRSA role WazuhManagerServiceAccountRole must have s3:GetObject + s3:ListBucket
#   - KMS key must allow Decrypt from the IRSA role
#
# IMPORTANT: This bucket must be created BEFORE configuring CloudTrail/GuardDuty
# log delivery in the source accounts.

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/s3/"
}

inputs = {
  bucket_name = "management-wazuh-aws-logs"
  service     = "wazuh"
  attributes  = "aws-logs-central"

  # Log objects are immutable; versioning adds cost
  versioning_enabled = false

  # SSE-KMS with AWS managed key
  kms_master_key_arn = ""  # Empty string = use default aws/s3 managed key
  sse_algorithm      = "AES256"

  # Enforce SSL-only access
  allow_ssl_requests_only = true

  # Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Bucket policy: cross-account CloudTrail/Config/GuardDuty/VPCFlowLogs delivery
  policy = file("bucket-policy.json")

  # Lifecycle rules
  lifecycle_configuration_rules = [
    {
      enabled = true
      id      = "raw-logs-tiering"

      abort_incomplete_multipart_upload_days = 7

      filter_and = {
        prefix = "AWSLogs/"
      }

      transition = [
        {
          days          = 90
          storage_class = "INTELLIGENT_TIERING"
        }
      ]

      # Expire raw logs after 1 year (Wazuh Indexer retains processed alerts)
      expiration = {
        days = 365
      }

      noncurrent_version_expiration = null
      noncurrent_version_transition = []
    }
  ]
}
