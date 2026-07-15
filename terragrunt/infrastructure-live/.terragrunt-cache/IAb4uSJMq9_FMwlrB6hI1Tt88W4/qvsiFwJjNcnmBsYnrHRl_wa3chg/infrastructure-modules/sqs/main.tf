locals {
  tags = {
    Namespace  = var.namespace
    Name       = var.name
    Stage      = var.stage
    Team       = "platform"
    Service    = var.service
    Attributes = var.attributes
  }
}

resource "aws_sqs_queue" "dlq_queue" {
  count                             = var.create_dlq ? 1 : 0
  name                              = "${var.namespace}-${var.stage}-${var.name}-dlq"
  name_prefix                       = var.name_prefix
  visibility_timeout_seconds        = var.visibility_timeout_seconds
  message_retention_seconds         = var.message_retention_seconds
  max_message_size                  = var.max_message_size
  delay_seconds                     = var.delay_seconds
  receive_wait_time_seconds         = var.receive_wait_time_seconds
  redrive_policy                    = var.redrive_policy
  fifo_queue                        = var.fifo_queue
  content_based_deduplication       = var.content_based_deduplication
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  tags                              = local.tags
}

resource "aws_sqs_queue" "queue" {
  count                      = var.create_sqs ? 1 : 0
  name                       = "${var.namespace}-${var.stage}-${var.name}"
  name_prefix                = var.name_prefix
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  redrive_policy = var.create_dlq == false ? var.redrive_policy : jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq_queue[count.index].arn
    maxReceiveCount     = var.max_receive_count
  })
  fifo_queue                        = var.fifo_queue
  content_based_deduplication       = var.content_based_deduplication
  kms_master_key_id                 = var.kms_master_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds
  tags                              = local.tags

}

resource "aws_sqs_queue_policy" "policy" {
  count     = var.create_sqs ? 1 : 0
  queue_url = aws_sqs_queue.queue[count.index].id
  policy    = var.policy
}

resource "aws_sqs_queue_policy" "dlq_policy" {
  count     = var.create_dlq == "" ? 1 : 0
  queue_url = aws_sqs_queue.dlq_queue[count.index].id
  policy    = var.dlq_policy
}

data "aws_sns_topic" "sns_topic" {
  count = var.create_sns_topic_subscription ? 1 : 0
  name  = var.sns_topic_name
}
resource "aws_sns_topic_subscription" "sns-topic" {
  count     = var.create_sns_topic_subscription ? 1 : 0
  topic_arn = var.sns_topic_name == "" ? var.sns_topic_arn : data.aws_sns_topic.sns_topic[count.index].arn
  protocol  = var.protocol
  endpoint  = aws_sqs_queue.queue.0.arn
}


