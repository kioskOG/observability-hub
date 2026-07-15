include {
  path = find_in_parent_folders()
}

locals {
  common_vars = yamldecode(file("${get_terragrunt_dir()}/../../common.yaml"))
}

terraform {
  source = "../../../../../..//infrastructure-modules/cloudfront"
}

inputs = {
  origin_type = "alb"
  bucket_name = ""

  alb_dns_name = "internal-myapp-alb-123456.ap-southeast-1.elb.amazonaws.com"
  acm_certificate_arn = "arn:aws:acm:us-east-1:547580490325:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

  # Cache TTLs
  min_ttl     = 0
  default_ttl = 3600
  max_ttl     = 86400

  # CloudFront price class
  price_class = "PriceClass_100"

  # Geo restriction
  geo_restriction_type = "none" # "none" | "blacklist" | "whitelist"

  # Optional WAFv2 WebACL ID (GLOBAL scope) to attach to CloudFront
  waf_web_acl_id = "" # e.g., "arn:aws:wafv2:us-east-1:547580490325:global/webacl/my-waf/abcd1234"

  # If your module also expects region anywhere else
  region               = local.common_vars["aws_region"]
}
