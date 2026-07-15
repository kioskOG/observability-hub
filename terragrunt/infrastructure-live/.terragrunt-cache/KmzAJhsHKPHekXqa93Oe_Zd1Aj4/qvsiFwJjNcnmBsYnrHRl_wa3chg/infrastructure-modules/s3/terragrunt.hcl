include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/s3/"
}

inputs = {
  namespace   = "mlops"
  stage       = "us-east-2"
  name        = "wazuh-saml-metadata-public"
  bucket_name = "wazuh-saml-metadata-public"
  
  versioning_enabled = false

  # We allow public read for this bucket to host the SAML metadata XML
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  
  # The module accepts a bucket policy string directly if needed,
  # but for a simple public file we can also just use AWS CLI `put-object --acl public-read`
  # if the ACLs aren't blocked, or we can provide a bucket policy.
  bucket_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::wazuh-saml-metadata-public/*"
    }
  ]
}
EOF

  tags = {
    "Name"       = "wazuh-saml-metadata-public"
    "Namespace"  = "mlops"
    "Service"    = "wazuh"
    "Stage"      = "us-east-2"
    "ManagedBy"  = "Terragrunt"
  }
}
