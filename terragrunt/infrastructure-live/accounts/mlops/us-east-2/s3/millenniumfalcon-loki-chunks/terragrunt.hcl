include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/s3/"
}

inputs = {
  namespace   = "mlops"
  stage       = "us-east-2"
  name        = "millenniumfalcon-loki-chunks"
  bucket_name = "millenniumfalcon-loki-chunks"

  versioning_enabled = true
  sse_algorithm      = "AES256"


  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    "Attributes" = "observability"
    "Name"       = "millenniumfalcon-loki-chunks"
    "Namespace"  = "mlops"
    "Service"    = "loki"
    "Stage"      = "us-east-2"
    "Team"       = "devops"
    "ManagedBy"  = "Terragrunt"
    "Project"    = "observability-hub"
  }
}
