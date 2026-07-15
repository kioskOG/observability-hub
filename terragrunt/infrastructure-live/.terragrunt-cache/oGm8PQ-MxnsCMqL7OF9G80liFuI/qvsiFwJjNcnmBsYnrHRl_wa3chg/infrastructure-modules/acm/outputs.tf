output "certificate_arn" {
  description = "ARN of the issued ACM certificate"
  value       = aws_acm_certificate.this.arn
}
output "certificate_status" {
  description = "Current status of the ACM certificate (PENDING_VALIDATION, ISSUED)"
  value       = aws_acm_certificate.this.status
}
output "domain_name" {
  value = aws_acm_certificate.this.domain_name
}
output "domain_validation_options" {
  description = "Domain validation options returned by ACM (name/type/value)"
  value       = aws_acm_certificate.this.domain_validation_options
}
output "validation_record_fqdns" {
  description = "FQDNs of the created Route53 validation records (if route53_zone_id provided)"
  value       = var.route53_zone_id != "" ? [for r in aws_route53_record.acm_validation : r.fqdn] : []
}
