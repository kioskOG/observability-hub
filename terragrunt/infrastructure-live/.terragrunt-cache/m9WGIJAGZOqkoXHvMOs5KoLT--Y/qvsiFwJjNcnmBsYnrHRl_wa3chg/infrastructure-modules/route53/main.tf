locals {
  zone_id = var.create_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id
}
# Create a hosted zone (optional)
resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name
  tags  = var.tags
  #   vpc {
  #     vpc_id = var.vpc_id
  #   }
}
# Optional Route 53 health checks
resource "aws_route53_health_check" "this" {
  for_each          = { for hc in var.health_checks : hc.name => hc }
  reference_name    = each.value.name
  fqdn              = lookup(each.value, "fqdn", null)
  port              = lookup(each.value, "port", null)
  type              = each.value.type # HTTP | HTTPS | TCP | CALCULATED | CLOUDWATCH_METRIC | ...
  resource_path     = lookup(each.value, "resource_path", null)
  failure_threshold = lookup(each.value, "failure_threshold", 3)
  request_interval  = lookup(each.value, "request_interval", 30)
  measure_latency   = lookup(each.value, "measure_latency", false)
  #   inverted                       = lookup(each.value, "inverted", false)
  enable_sni                      = lookup(each.value, "enable_sni", null)
  regions                         = lookup(each.value, "regions", null)
  disabled                        = lookup(each.value, "disabled", false)
  insufficient_data_health_status = lookup(each.value, "insufficient_data_health_status", null)
  tags                            = lookup(each.value, "tags", {})
}
# Helper map to reference health checks by name from records
locals {
  health_check_ids = { for k, v in aws_route53_health_check.this : k => v.id }
}
# Core DNS records (supports standard, ALIAS, and all routing policies)
resource "aws_route53_record" "records" {
  # for_each = { for r in var.records : "${r.name}~${r.type}~${lookup(r, "set_identifier", "")}" => r }
  for_each = {
    for r in var.records :
    "${r.name}~${r.type}~${try(r.set_identifier != null ? r.set_identifier : "", "")}" => r
  }
  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  allow_overwrite = lookup(each.value, "allow_overwrite", false)
  # TTL only when not alias
  ttl     = contains(["A", "AAAA", "CNAME", "MX", "TXT", "SRV", "NS"], each.value.type) && try(each.value.alias.name, null) == null ? lookup(each.value, "ttl", 300) : null
  records = try(each.value.records, null)
  # ALIAS (dynamic so it's only emitted when alias is provided)
  dynamic "alias" {
    for_each = try(each.value.alias.name, null) != null ? [1] : []
    content {
      name                   = each.value.alias.name
      zone_id                = each.value.alias.zone_id
      evaluate_target_health = lookup(each.value.alias, "evaluate_target_health", false)
    }
  }
  # Routing policies
  # set_identifier = lookup(each.value, "set_identifier", null)
  set_identifier = try(each.value.set_identifier, null)
  dynamic "weighted_routing_policy" {
    for_each = lookup(each.value, "weighted_routing_policy", null) != null ? [each.value.weighted_routing_policy] : []
    content {
      weight = weighted_routing_policy.value.weight
    }
  }
  dynamic "latency_routing_policy" {
    for_each = lookup(each.value, "latency_routing_policy", null) != null ? [each.value.latency_routing_policy] : []
    content {
      region = latency_routing_policy.value.region
    }
  }
  dynamic "failover_routing_policy" {
    for_each = lookup(each.value, "failover_routing_policy", null) != null ? [each.value.failover_routing_policy] : []
    content {
      type = failover_routing_policy.value.type # PRIMARY or SECONDARY
    }
  }
  dynamic "geolocation_routing_policy" {
    for_each = lookup(each.value, "geolocation_routing_policy", null) != null ? [each.value.geolocation_routing_policy] : []
    content {
      continent   = lookup(geolocation_routing_policy.value, "continent", null)
      country     = lookup(geolocation_routing_policy.value, "country", null)
      subdivision = lookup(geolocation_routing_policy.value, "subdivision", null)
    }
  }
  multivalue_answer_routing_policy = lookup(each.value, "multivalue_answer_routing_policy", null)
  health_check_id = try(
    length(lookup(each.value, "health_check_name", "")) > 0 ? local.health_check_ids[each.value.health_check_name] : null,
    lookup(each.value, "health_check_id", null)
  )
}
