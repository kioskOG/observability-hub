output "zone_id" {
  value       = local.zone_id
  description = "Hosted zone ID in use"
}
output "name_servers" {
  value       = try(aws_route53_zone.this[0].name_servers, null)
  description = "Name servers for the hosted zone (only when create_zone = true)"
}
output "record_fqdns" {
  description = "Map of created records (keyed by name@type@set_identifier)"
  value       = { for k, r in aws_route53_record.records : k => r.fqdn }
}
output "health_check_ids" {
  description = "Map of health check name => id"
  value       = local.health_check_ids
}