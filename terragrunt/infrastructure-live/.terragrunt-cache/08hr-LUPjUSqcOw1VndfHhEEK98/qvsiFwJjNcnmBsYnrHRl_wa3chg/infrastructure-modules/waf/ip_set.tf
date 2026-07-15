resource "aws_wafv2_ip_set" "ip_set" {
  for_each           = var.ip_set_addresses
  name               = each.key
  description        = each.value.description
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = each.value.addresses

  tags = var.tags
}