include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../../..//infrastructure-modules/acm/"
}

inputs = {
  service    = path_relative_to_include()
  attributes = "acm"
  
  domain_name                 = "short-url.dev.linuxforall.in"
  subject_alternative_names   = "*.short-url.dev.linuxforall.in"

  # Hosted zone id so it can create DNS validation records.
  route53_zone_id             = "Z06855293IGXCZX9DNUEH"

  # Optional: tweak validation record TTLs (defaults shown)

  acm_validation_ttl          = 60
  acm_validation_ttl_map      = {
    # "short-url.dev.linuxforall.in" = 300
  }
  tags = {
    Namespace = "dev"
    Stage     = "dev"
    Team      = "DevOps"
    Service   = path_relative_to_include()
    Attributes= "acm"
  }
}

