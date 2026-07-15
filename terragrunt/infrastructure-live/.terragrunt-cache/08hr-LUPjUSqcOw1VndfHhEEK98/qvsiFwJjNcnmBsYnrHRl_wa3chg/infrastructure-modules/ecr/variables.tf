variable "region" {
  description = "AWS region"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace, which could be your organization name, e.g. 'eg' or 'cp'"
  type        = string
  default     = ""
}

variable "stage" {
  description = "Stage, e.g. 'prod', 'staging', 'dev' or 'testing'"
  type        = string
  default     = ""
}

variable "repositories" {
  description = "Required repository names in list"
  type        = any
}

variable "service" {
  description = "Service name identifier, like Name or Github repository"
  type        = string
  default     = ""
}

variable "attributes" {
  description = "Custom attributes signifying purpose of resource"
  type        = string
  default     = "unknown"
}

variable "image_scaning_enable" {
  description = "Custome value to enable scaning on AWS ECR"
  type        = bool
  default     = false
}

variable "enable_expiry" {
  description = "Lifecycle policy for expiry"
  type        = bool
  default     = true
}

variable "expiry_policy" {
  description = "The expiry policy document"
  type        = any
}

variable "scanning_rules" {
  description = "Scanning rule for ECR"
  type        = any
  default = {
    "rule1" = {
      scan_frequency = "CONTINUOUS_SCAN"
      filter         = "*"
      filter_type    = "WILDCARD"
    }
  }
}
