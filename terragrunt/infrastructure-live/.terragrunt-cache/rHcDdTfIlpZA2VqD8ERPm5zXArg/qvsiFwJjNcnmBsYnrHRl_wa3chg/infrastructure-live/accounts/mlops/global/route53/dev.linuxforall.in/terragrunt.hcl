include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/route53"
}

locals {
  common_vars = yamldecode(file("${get_terragrunt_dir()}/../../common.yaml"))
}

inputs = {
  create_zone = true
  # existing_zone_id = "Z036279435YYM5MTK0095"
  domain_name = "prod.jatinog.com"
  records = [
    {
      name    = "meet.prod.jatinog.com"
      type    = "A"
      ttl     = 60
      records = ["54.169.208.237"]
    }
  ]
  tags = {
    "Name"       = "short-url-db",
    "env"        = local.common_vars["env_name"],
    "Team"       = "DevOps",
    "Org"        = "SystemEngg"
  }

  # acm_validation_records = [
  #   {
  #     name    = "short-url.dev.linuxforall.in"
  #     type    = "CNAME"
  #     records = ["_fghij67890.acm-validations.aws."]
  #     ttl     = 300
  #   }
  # ]
}

# tested