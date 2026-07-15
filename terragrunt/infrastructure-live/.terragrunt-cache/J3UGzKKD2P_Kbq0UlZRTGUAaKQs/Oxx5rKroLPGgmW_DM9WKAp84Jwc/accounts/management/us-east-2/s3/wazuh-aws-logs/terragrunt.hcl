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
# Encryption: SSE-KMS (AWS managed key or custom CMK)
# Lifecycle:
#   - Standard → Intelligent Tiering at 90 days
#   - Expire at 365 days (raw logs; Wazuh Indexer retains processed alerts)
#
# Bucket Policy: Allows CloudTrail, Config, GuardDuty, and VPC Flow Logs
#                delivery from all 4 accounts.
#
# SQS Notifications: S3 event notifications → SQS queue for Wazuh consumption
#                    (see ../sqs/wazuh-aws-logs-notify/)
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

# TODO: Replace with actual S3 module source from infrastructure-modules
# terraform {
#   source = "../../../../../..//infrastructure-modules/s3/"
# }

# inputs = {
#   bucket_name = "management-wazuh-aws-logs"
#
#   versioning = false   # Log objects are immutable; versioning adds cost
#
#   server_side_encryption = {
#     sse_algorithm     = "aws:kms"
#     # kms_master_key_id = "<CUSTOM_CMK_ARN>"   # Optional: use custom CMK
#   }
#
#   lifecycle_rules = [
#     {
#       id      = "raw-logs-tiering"
#       enabled = true
#       prefix  = "AWSLogs/"
#
#       transition = [
#         {
#           days          = 90
#           storage_class = "INTELLIGENT_TIERING"
#         }
#       ]
#
#       # Expire raw logs after 1 year (Wazuh Indexer retains processed alerts)
#       expiration = {
#         days = 365
#       }
#     }
#   ]
#
#   # Block all public access
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
#
#   tags = {
#     Service   = "wazuh"
#     Component = "aws-logs-central"
#     ManagedBy = "Terraform"
#   }
# }
