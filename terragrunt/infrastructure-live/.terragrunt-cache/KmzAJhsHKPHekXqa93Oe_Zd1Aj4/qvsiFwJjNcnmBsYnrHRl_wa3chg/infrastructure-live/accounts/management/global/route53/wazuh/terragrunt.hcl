# Route53 — Wazuh Dashboard DNS
#
# TODO: This is a placeholder. Fill in the Route53 zone ID and record details
# once the internal hosted zone is confirmed.
#
# Expected record: wazuh.int.generic.com → ALB
# Type: CNAME or A (alias to ALB)

include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/route53/"
}

inputs = {
  # TODO: Uncomment and configure once the Route53 module and zone are set up
  # zone_id = "<INTERNAL_HOSTED_ZONE_ID>"
  # records = {
  #   "wazuh.int.generic.com" = {
  #     type    = "CNAME"
  #     ttl     = 300
  #     records = ["<ALB_DNS_NAME>"]
  #   }
  # }
}
