# Create the certificate
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = try(var.subject_alternative_names, [])
  validation_method         = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }

}

# Build a map of domain -> validation option (resource_record_name/value/type)
locals {
  dvo_map = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    "${dvo.domain_name}" => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
      domain = dvo.domain_name
    }
  }
}

# Create Route53 validation records (only if route53_zone_id provided)
resource "aws_route53_record" "acm_validation" {
  for_each = var.route53_zone_id != "" ? local.dvo_map : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = lookup(var.acm_validation_ttl_map, each.value.domain, var.acm_validation_ttl)
  records = [each.value.value]

  allow_overwrite = true
}

# ACM certificate validation resource — waits for DNS to propagate
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = var.route53_zone_id != "" ? [for r in aws_route53_record.acm_validation : r.fqdn] : [] # if user will validate manually, leave empty

  # Terraform will automatically handle the dependency on aws_route53_record.acm_validation
  # when route53_zone_id is provided since validation_record_fqdns references it
}
