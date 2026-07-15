# variable "price_class" {
#   type        = string
#   default     = "PriceClass_200"
#   description = "Price class for this distribution: `PriceClass_All`, `PriceClass_200`, `PriceClass_100`"
# }


# variable "site_aliases" {
#   type        = list(string)
#   description = "List of FQDN's - Used to set the Alternate Domain Names (CNAMEs) setting on Cloudfront"
#   default     = []
# }

# variable "region" {
#   type        = string
#   description = "The AWS region this distribution should reside in."
# }

# variable "minimum_protocol_version" {
#   type        = string
#   description = <<-EOT
#     Cloudfront TLS minimum protocol version.
#     If `var.acm_certificate_arn` is unset, only "TLSv1" can be specified. See: [AWS Cloudfront create-distribution documentation](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/create-distribution.html)
#     and [Supported protocols and ciphers between viewers and CloudFront](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html#secure-connections-supported-ciphers) for more information.
#     Defaults to "TLSv1.2_2019" unless `var.acm_certificate_arn` is unset, in which case it defaults to `TLSv1`
#     EOT
#   default     = "TLSv1.2_2021"
# }

# variable "acm_certificate_arn" {
#   type        = string
#   description = "Existing ACM Certificate ARN"
#   default     = ""
# }

# variable "http_version" {
#   type        = string
#   default     = "http2and3"
#   description = "The maximum HTTP version to support on the distribution. Allowed values are http1.1, http2, http2and3 and http3"
# }

# variable "origin_access_identities" {
#   description = "Map of CloudFront origin access identities (value as a comment)"
#   type        = map(string)
#   default     = {}
# }

# variable "create_origin_access_identity" {
#   description = "Controls if CloudFront origin access identity should be created"
#   type        = bool
#   default     = false
# }

# variable "retain_on_delete" {
#   description = "Disables the distribution instead of deleting it when destroying the resource through Terraform. If this is set, the distribution needs to be deleted manually afterwards."
#   type        = bool
#   default     = false
# }

# variable "wait_for_deployment" {
#   description = "If enabled, the resource will wait for the distribution status to change from InProgress to Deployed. Setting this to false will skip the process."
#   type        = bool
#   default     = true
# }

# variable "default_root_object" {
#   description = "The object that you want CloudFront to return (for example, index.html) when an end user requests the root URL."
#   type        = string
#   default     = null
# }

# variable "is_ipv6_enabled" {
#   description = "Whether the IPv6 is enabled for the distribution."
#   type        = bool
#   default     = true
# }

# variable "comment" {
#   description = "Any comments you want to include about the distribution."
#   type        = string
#   default     = "Managed by Terraform"
# }

# variable "enabled" {
#   description = "Whether the distribution is enabled to accept end user requests for content."
#   type        = bool
#   default     = true
# }

# variable "create_origin_access_control" {
#   description = "Controls if CloudFront origin access control should be created"
#   type        = bool
#   default     = false
# }

# variable "origin_access_control" {
#   description = "Map of CloudFront origin access control"
#   type = map(object({
#     description      = string
#     origin_type      = string
#     signing_behavior = string
#     signing_protocol = string
#   }))

#   default = {
#     s3 = {
#       description      = "",
#       origin_type      = "s3",
#       signing_behavior = "always",
#       signing_protocol = "sigv4"
#     }
#   }
# }

# variable "ordered_cache_behavior" {
#   description = "An ordered list of cache behaviors resource for this distribution. List from top to bottom in order of precedence. The topmost cache behavior will have precedence 0."
#   type        = any
#   default     = []
# }

# variable "default_cache_behavior" {
#   description = "The default cache behavior for this distribution"
#   type        = any
#   default     = null
# }

# variable "origin" {
#   description = "One or more origins for this distribution (multiples allowed)."
#   type        = any
#   default     = null
# }

# variable "logging_config" {
#   description = "The logging configuration that controls how logs are written to your distribution (maximum one)."
#   type        = any
#   default     = {}
# }

# variable "web_acl_id" {
#   description = "If you're using AWS WAF to filter CloudFront requests, the Id of the AWS WAF web ACL that is associated with the distribution. The WAF Web ACL must exist in the WAF Global (CloudFront) region and the credentials configuring this argument must have waf:GetWebACL permissions assigned. If using WAFv2, provide the ARN of the web ACL."
#   type        = string
#   default     = null
# }

# variable "create_response_headers_policy" {
#   description = "create response headers policy for cloudfront"
#   type        = bool
#   default     = false
# }

# variable "response_headers_policy_name" {
#   description = "(Required) A unique name to identify the CloudFront Origin Request Policy."
#   type        = string
#   default     = null
# }
# variable "response_headers_policy_description" {
#   description = "(Optional) The description of the origin request policy."
#   type        = string
#   default     = null
# }
# variable "response_headers_policy_cors" {
#   description = "(Optional) A configuration for a set of HTTP response headers for CORS(Cross-Origin Resource Sharing)."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_custom_headers" {
#   description = "(Optional) A configuration for specifying the custom HTTP headers in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_server_timing_header" {
#   description = "(Optional) A configuration for `Server-Timing` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_content_security_policy_header" {
#   description = "(Optional) A configuration for `Content-Security-Policy` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_content_type_options_header" {
#   description = "(Optional) A configuration for `X-Content-Type-Options` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_frame_options_header" {
#   description = "(Optional) A configuration for `X-Frame-Options` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_referrer_policy_header" {
#   description = "(Optional) A configuration for `Referrer-Policy` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_strict_transport_security_header" {
#   description = "(Optional) A configuration for `Strict-Transport-Security` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }
# variable "response_headers_policy_xss_protection_header" {
#   description = "(Optional) A configuration for `X-XSS-Protection` header in HTTP responses sent from CloudFront."
#   type        = any
#   default     = null
# }


# variable "region" {
#   type        = string
#   description = "Primary AWS region for non-CloudFront resources."
# }

# # What sits behind CloudFront? "s3" | "alb" | "nlb"
# variable "origin_type" {
#   type        = string
#   default     = "s3"
#   description = "Origin type: s3 | alb | nlb"
# }

# # S3 origin
# variable "bucket_name" {
#   type        = string
#   default     = ""
#   description = "Name of existing S3 bucket (required when origin_type = s3)."
# }

# # ALB/NLB origin (custom origin)
# variable "alb_dns_name" {
#   type        = string
#   default     = ""
#   description = "DNS name of ALB/NLB when origin_type != s3."
# }

# variable "origin_protocol_policy" {
#   type        = string
#   default     = "https-only"
#   description = "http-only | https-only | match-viewer"
# }

# variable "origin_http_port" {
#   type        = number
#   default     = 80
#   description = "HTTP port for custom origin."
# }

# variable "origin_https_port" {
#   type        = number
#   default     = 443
#   description = "HTTPS port for custom origin."
# }

# # CloudFront behaviors
# variable "default_root_object" {
#   type        = string
#   default     = "index.html"
#   description = "Default root object."
# }

# variable "aliases" {
#   type        = list(string)
#   default     = []
#   description = "CNAMEs for the CloudFront distribution."
# }

# variable "acm_certificate_arn_us_east_1" {
#   type        = string
#   default     = ""
#   description = "ACM cert ARN in us-east-1 for CloudFront. Leave blank to use default CF cert."
# }

# variable "compress" {
#   type        = bool
#   default     = true
#   description = "Enable on-the-fly compression (gzip/brotli)."
# }

# variable "min_ttl" {
#   type    = number
#   default = 0
# }

# variable "default_ttl" {
#   type    = number
#   default = 3600
# }

# variable "max_ttl" {
#   type    = number
#   default = 86400
# }

# variable "price_class" {
#   type    = string
#   default = "PriceClass_100"
#   description = "PriceClass_100 | PriceClass_200 | PriceClass_All"
# }

# variable "enable_ipv6" {
#   type    = bool
#   default = true
# }

# # Geo restrictions
# variable "geo_restriction_type" {
#   type        = string
#   default     = "none"
#   description = "none | whitelist | blacklist"
# }

# variable "geo_restriction_locations" {
#   type        = list(string)
#   default     = []
#   description = "List of country codes for whitelist/blacklist."
# }

# # Logging
# variable "enable_logging" {
#   type        = bool
#   default     = false
# }

# variable "logging_bucket" {
#   type        = string
#   default     = ""
#   description = "S3 bucket for logs (without s3://)."
# }

# variable "logging_prefix" {
#   type        = string
#   default     = "cloudfront-logs/"
# }

# # Optional WAF (CLOUDFRONT scope)
# variable "waf_web_acl_arn" {
#   type        = string
#   default     = ""
#   description = "WAFv2 Web ACL ARN (scope=CLOUDFRONT). Leave empty to skip."
# }



variable "region" {
  type = string
}
variable "origin_type" {
  description = "Choose origin type: 's3' or 'alb'"
  type        = string
  default     = "s3"
}
variable "bucket_name" {
  type = string
}
variable "alb_dns_name" {
  type    = string
  default = ""
}
variable "min_ttl" {
  type    = number
  default = 0
}
variable "default_ttl" {
  type    = number
  default = 3600
}
variable "max_ttl" {
  type    = number
  default = 86400
}
variable "price_class" {
  type    = string
  default = "PriceClass_100"
}
variable "geo_restriction_type" {
  type    = string
  default = "none"
}
variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for CloudFront HTTPS"
}
variable "waf_web_acl_id" {
  type        = string
  description = "AWS WAF Web ACL ID to associate with CloudFront"
  default     = ""
}