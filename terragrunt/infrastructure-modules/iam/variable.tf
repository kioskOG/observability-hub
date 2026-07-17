variable "iam_user" {
  type    = any
  default = {}
}

variable "iam_role" {
  type    = any
  default = {}
}

variable "iam_policy" {
  type    = list(string)
  default = []
}

variable "policy_vars" {
  type        = any
  default     = {}
  description = "Variables to pass to templatefile when evaluating custom policy JSON files"
}

variable "additional_tags" {
  type = map(any)
  default = {
    "ManagedBy" = "Terraform"
  }
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "oidc" {
  type        = any
  description = "Whether to create OIDC or not"
  default     = {}
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC Issuer URL for IRSA trust policies"
  default     = ""
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN for IRSA trust policies"
  default     = ""
}