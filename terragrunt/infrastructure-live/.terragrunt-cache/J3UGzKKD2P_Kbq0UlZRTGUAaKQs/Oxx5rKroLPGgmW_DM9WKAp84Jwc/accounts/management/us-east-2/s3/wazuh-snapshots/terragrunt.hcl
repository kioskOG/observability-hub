# S3 Bucket — Wazuh Indexer Snapshots
#
# Bucket: management-wazuh-snapshots
# Purpose: S3 snapshot repository for Wazuh Indexer (repository-s3 plugin)
# Encryption: SSE-KMS (default AWS managed key)
# Lifecycle: Objects transition to Glacier Deep Archive after 90 days (cold window)
#
# Dependencies:
#   - IRSA role WazuhIndexerSnapshotsRole (Phase 2, IAM stack)
#
# This stack should be applied BEFORE registering the S3 snapshot repository
# in the Wazuh Indexer.

include {
  path = find_in_parent_folders()
}

# TODO: Replace with actual S3 module source from infrastructure-modules
# terraform {
#   source = "../../../../../..//infrastructure-modules/s3/"
# }

# inputs = {
#   bucket_name = "management-wazuh-snapshots"
#
#   versioning = true
#
#   server_side_encryption = {
#     sse_algorithm = "aws:kms"
#   }
#
#   lifecycle_rules = [
#     {
#       id      = "wazuh-cold-tier"
#       enabled = true
#       prefix  = ""
#
#       transition = [
#         {
#           days          = 90
#           storage_class = "GLACIER_DEEP_ARCHIVE"
#         }
#       ]
#
#       # Keep snapshots for 1 year total, then expire
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
#     Component = "indexer-snapshots"
#     ManagedBy = "Terraform"
#   }
# }
