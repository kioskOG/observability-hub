variable "region" {
  type        = string
  description = "AWS region"
}

variable "bucket_id" {
  type        = string
  description = "The name (ID) of the S3 bucket to configure notifications on"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the SQS queue to receive S3 event notifications"
}

variable "events" {
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
  description = "List of S3 event types to trigger notifications"
}

variable "filter_prefix" {
  type        = string
  default     = ""
  description = "S3 key prefix filter for event notifications"
}

variable "filter_suffix" {
  type        = string
  default     = ""
  description = "S3 key suffix filter for event notifications"
}
