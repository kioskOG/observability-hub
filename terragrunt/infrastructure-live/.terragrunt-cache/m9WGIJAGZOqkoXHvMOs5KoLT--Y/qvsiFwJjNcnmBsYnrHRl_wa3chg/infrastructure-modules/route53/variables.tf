variable "region" {
  type = string
}
variable "create_zone" {
  description = "Whether to create a new hosted zone (true) or use an existing one (false)"
  type        = bool
  default     = true
}
variable "domain_name" {
  description = "Domain name for the hosted zone (required if create_zone = true)"
  type        = string
  default     = null
}
variable "existing_zone_id" {
  description = "Use an existing hosted zone ID (required if create_zone = false)"
  type        = string
  default     = null
}
# variable "vpc_id" {
#   description = "VPC ID to associate for private hosted zone"
#   type        = string
#   default     = null
# }
variable "tags" {
  description = "Tags for hosted zone and health checks"
  type        = map(string)
  default     = {}
}
# Health checks you want to create and later attach by name
variable "health_checks" {
  description = <<EOT
List of health checks to create. Reference them in records via `health_check_name`.
Example:
[
  {
    name  = "api-health"
    type  = "HTTPS"
    fqdn  = "api.example.com"
    port  = 443
    resource_path = "/healthz"
  }
]
EOT
  type = list(object({
    name                            = string
    type                            = string
    fqdn                            = optional(string)
    port                            = optional(number)
    resource_path                   = optional(string)
    failure_threshold               = optional(number)
    request_interval                = optional(number)
    measure_latency                 = optional(bool)
    inverted                        = optional(bool)
    enable_sni                      = optional(bool)
    regions                         = optional(list(string))
    disabled                        = optional(bool)
    insufficient_data_health_status = optional(string)
    tags                            = optional(map(string))
  }))
  default = []
}
# Main records list
variable "records" {
  description = <<EOT
Records to create. Supports ALIAS and routing policies.
Examples entries:
{
  name = "www.example.com"
  type = "A"
  ttl  = 300
  records = ["1.2.3.4"]
}
{
  name = "app.example.com"
  type = "A"
  alias = {
    name                   = "d123.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
# Weighted example (two records share same name+type but different set_identifier)
{
  name           = "blue.example.com"
  type           = "A"
  set_identifier = "blue"
  ttl            = 60
  records        = ["10.0.0.10"]
  weighted_routing_policy = { weight = 20 }
}
{
  name           = "blue.example.com"
  type           = "A"
  set_identifier = "green"
  ttl            = 60
  records        = ["10.0.0.11"]
  weighted_routing_policy = { weight = 80 }
}
# Failover example (attach a health check)
{
  name           = "api.example.com"
  type           = "A"
  set_identifier = "primary"
  ttl            = 30
  records        = ["10.0.1.10"]
  failover_routing_policy = { type = "PRIMARY" }
  health_check_name = "api-health"
}
{
  name           = "api.example.com"
  type           = "A"
  set_identifier = "secondary"
  ttl            = 30
  records        = ["10.0.2.10"]
  failover_routing_policy = { type = "SECONDARY" }
}
EOT
  type = list(object({
    name = string
    type = string
    # Standard records
    ttl             = optional(number)
    records         = optional(list(string))
    allow_overwrite = optional(bool, false)
    # Alias (mutually exclusive with 'records')
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = optional(bool, false)
    }))
    # Routing policies
    set_identifier          = optional(string)
    weighted_routing_policy = optional(object({ weight = number }))
    latency_routing_policy  = optional(object({ region = string }))
    failover_routing_policy = optional(object({ type = string })) # PRIMARY | SECONDARY
    geolocation_routing_policy = optional(object({
      continent   = optional(string)
      country     = optional(string)
      subdivision = optional(string)
    }))
    multivalue_answer_routing_policy = optional(bool)
    # Health check
    # Prefer 'health_check_name' (created in this module); or pass 'health_check_id' directly.
    health_check_name = optional(string)
    health_check_id   = optional(string)
  }))
  default = []
}
# Simple helper for ACM validation records (CNAMEs)
variable "acm_validation_records" {
  description = <<EOT
Optional CNAME records for ACM DNS validation.
Example:
[
  {
    name    = "_12345abcde.example.com"
    type    = "CNAME"
    ttl     = 300
    records = ["_67890fghij.acm-validations.aws."]
  }
]
EOT
  type = list(object({
    name            = string
    type            = string
    ttl             = optional(number)
    records         = list(string)
    allow_overwrite = optional(bool)
  }))
  default = []
}
