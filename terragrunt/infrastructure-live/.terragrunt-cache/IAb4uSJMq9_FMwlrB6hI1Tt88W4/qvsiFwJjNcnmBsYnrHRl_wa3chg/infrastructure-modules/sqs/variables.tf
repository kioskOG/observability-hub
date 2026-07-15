variable "region" {
  type        = string
  description = "AWS region"
}

variable "aws_assume_role_arn" {
  type    = string
  default = ""
}

variable "namespace" {
  type        = string
  description = "Namespace, which could be your organization name, e.g. 'eg' or 'cp'"
}

variable "stage" {
  type        = string
  description = "Stage, e.g. 'prod', 'staging', 'dev' or 'testing'"
}

variable "service" {
  type        = string
  default     = ""
  description = "Github repo for required resource, empty value will make it gitops repo"
}

variable "attributes" {
  type        = string
  default     = "unknown"
  description = "Custom attributes signifying purpose of resource"
}

variable "name" {
  description = "This is the human-readable name of the queue. If omitted, Terraform will assign a random name."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "A unique name beginning with the specified prefix."
  type        = string
  default     = null
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue. An integer from 0 to 43200 (12 hours)"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message. Integer representing seconds, from 60 (1 minute) to 1209600 (14 days)"
  type        = number
  default     = 345600
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it. An integer from 1024 bytes (1 KiB) up to 262144 bytes (256 KiB)"
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed. An integer from 0 to 900 (15 minutes)"
  type        = number
  default     = 60
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive (long polling) before returning. An integer from 0 to 20 (seconds)"
  type        = number
  default     = 0
}

variable "policy" {
  description = "The JSON policy for the SQS queue"
  type        = string
  default     = ""
}

variable "dlq_policy" {
  description = "The JSON policy for the SQS queue"
  type        = string
  default     = ""
}

variable "redrive_policy" {
  description = "The JSON policy to set up the Dead Letter Queue, see AWS docs. Note: when specifying maxReceiveCount, you must specify it as an integer (5), and not a string (\"5\")"
  type        = string
  default     = ""
}

variable "fifo_queue" {
  description = "Boolean designating a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enables content-based deduplication for FIFO queues"
  type        = bool
  default     = false
}

variable "kms_master_key_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SQS or a custom CMK"
  type        = string
  default     = null
}

variable "kms_data_key_reuse_period_seconds" {
  description = "The length of time, in seconds, for which Amazon SQS can reuse a data key to encrypt or decrypt messages before calling AWS KMS again. An integer representing seconds, between 60 seconds (1 minute) and 86,400 seconds (24 hours)"
  type        = number
  default     = 300
}

variable "max_receive_count" {
  description = "Max Receive Count for SQS"
  type        = number
  default     = 5
}

variable "create_dlq" {
  description = "To check if dlq queue to be created or not"
  type        = bool
  default     = false
}

variable "create_sqs" {
  description = "To check if dlq queue to be created or not"
  type        = bool
  default     = true
}

variable "alarm_enabled" {
  type        = bool
  default     = false
  description = "A true/false for whether the alarms are created in the desired environment"
}

variable "evaluation_period" {
  type        = string
  default     = "5"
  description = "The evaluation period over which to use when triggering alarms."
}

variable "statistic_period" {
  type        = string
  default     = "60"
  description = "The number of seconds that make each statistic period."
}

variable "actions_alarm" {
  type        = list(any)
  default     = []
  description = "A list of actions to take when alarms are triggered. Will likely be an SNS topic for event distribution."
}

variable "actions_ok" {
  type        = list(any)
  default     = []
  description = "A list of actions to take when alarms are cleared. Will likely be an SNS topic for event distribution."
}

variable "NumberOfMessagesReceived" {
  description = "the number of NumberOfMessagesReceived"
  type        = number
  default     = 300
}

variable "NumberOfMessagesSent" {
  description = "the number of NumberOfMessagesSent"
  type        = number
  default     = 300
}

variable "ApproximateNumberOfMessagesDelayed" {
  description = "the number of ApproximateNumberOfMessagesDelayed"
  type        = number
  default     = 300
}

variable "ApproximateNumberOfMessagesVisible" {
  description = "the number of ApproximateNumberOfMessagesVisible"
  type        = number
  default     = 300
}

variable "protocol" {
  type        = string
  default     = "sqs"
  description = "SNS provider for sunscriptons"
}


variable "sns_topic_name" {
  type        = string
  default     = ""
  description = "SNS endpoint for sunscriptons"
}

variable "sns_topic_arn" {
  type        = string
  default     = ""
  description = "SNS arn for sunscriptons"
}

variable "create_sns_topic_subscription" {
  description = "SNS topic subscription"
  type        = bool
  default     = false
}

