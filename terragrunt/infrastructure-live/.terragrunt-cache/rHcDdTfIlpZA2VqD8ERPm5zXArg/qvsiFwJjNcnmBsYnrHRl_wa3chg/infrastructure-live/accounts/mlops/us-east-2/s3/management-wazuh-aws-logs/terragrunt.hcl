include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/s3/"
}

inputs = {
  namespace   = "mlops"
  stage       = "us-east-2"
  name        = "management-wazuh-aws-logs"
  bucket_name = "management-wazuh-aws-logs"
  
  # Bucket name structure from module will be overridden by bucket_name
  
  versioning_enabled = false

  sse_algorithm      = "aws:kms"
  # Using AWS managed key aws/s3 since no custom KMS is provided right now

  lifecycle_configuration_rules = [
    {
      id      = "wazuh-snapshot-transition"
      enabled = true

      # filter_and = {} is required by the module for empty filters, but the module handles null
      filter_and = null

      # Transition to GLACIER deep archive after 90 days to save costs
      transition = [
        {
          days          = 90
          storage_class = "DEEP_ARCHIVE"
        }
      ]

      # Expire completely after 1 year
      expiration = {
        days = 365
      }

      noncurrent_version_expiration = null
      noncurrent_version_transition = []
      abort_incomplete_multipart_upload_days = null
    }
  ]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # Bucket policy: CloudTrail/GuardDuty/VPCFlowLogs delivery
  policy = file("bucket-policy.json")

  tags = {
    "Attributes" = "mlops"
    "Name"       = "management-wazuh-aws-logs"
    "Namespace"  = "mlops"
    "Service"    = "wazuh"
    "Stage"      = "us-east-2"
    "Team"       = "devops"
    "ManagedBy"  = "Terragrunt"
  }
}
