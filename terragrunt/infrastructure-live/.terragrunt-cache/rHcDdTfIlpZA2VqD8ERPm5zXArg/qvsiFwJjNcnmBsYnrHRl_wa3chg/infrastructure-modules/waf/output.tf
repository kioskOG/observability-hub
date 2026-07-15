output "web_acl_arn" {
  description = "The ARN of the WAF WebACL."
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "The id of the WAF WebACL."
  value       = aws_wafv2_web_acl.main.id
}

output "ip_set_arn" {
  description = "The arn of the IP set."
  value       = { for k, v in aws_wafv2_ip_set.ip_set : k => v.arn }
}

output "ip_set_id" {
  description = "The id of the IP set."
  value       = { for k, v in aws_wafv2_ip_set.ip_set : k => v.id }
}