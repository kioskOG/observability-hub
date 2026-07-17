variable "secrets" {
  description = "A map of secrets to publish, where the key is the secret name and the value is the secret content."
  type = map(object({
    description = optional(string, "Published by Terraform")
    values      = map(string)
    kms_key_id  = optional(string)
    tags        = optional(map(string), {})
  }))
}

variable "region" {
  type        = string
  description = "AWS region"
}
