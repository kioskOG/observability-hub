variable "domain_name" {
  description = "Primary domain name for the certificate (e.g. example.com)"
  type        = string
}
variable "subject_alternative_names" {
  description = "List of SANs (additional domains) for the certificate"
  type        = list(string)
  default     = []
}
variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID to create ACM validation records. Leave empty to skip automatic DNS validation."
  type        = string
  default     = ""
}
variable "acm_validation_ttl" {
  description = "Default TTL for the ACM validation CNAME records"
  type        = number
  default     = 300
}
variable "acm_validation_ttl_map" {
  description = "Optional map domain -> ttl if you want different TTL per domain"
  type        = map(number)
  default     = {}
}
variable "tags" {
  description = "Tags to apply to certificate and records"
  type        = map(string)
  default     = {}
}
# Optional: allow callers to send a provider object to module (for regional/global differences).
# Pass in providers map in module call: providers = { aws = aws.acm } where aws.acm is an aliased provider
variable "region" {
  description = "Optional provider to use for ACM resources (pass provider reference to support us-east-1 use-case)"
  type        = any
  default     = null
}
