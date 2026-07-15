resource "aws_cloudwatch_metric_alarm" "numberofmessagesreceived_too_high" {
  count               = var.alarm_enabled ? 1 : 0
  alarm_name          = "${aws_sqs_queue.queue[count.index].name}-High-NumberOfMessagesReceived"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "NumberOfMessagesReceived"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Average"
  threshold           = var.NumberOfMessagesReceived
  alarm_description   = "This metric monitors SQS NumberOfMessagesReceived"
  alarm_actions       = var.actions_alarm

  dimensions = {
    QueueName = aws_sqs_queue.queue[count.index].name
  }
}

resource "aws_cloudwatch_metric_alarm" "numberofmessagessent_too_high" {
  count               = var.alarm_enabled ? 1 : 0
  alarm_name          = "${aws_sqs_queue.queue[count.index].name}-High-NumberOfMessagesSent"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "NumberOfMessagesSent"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Average"
  threshold           = var.NumberOfMessagesSent
  alarm_description   = "This metric monitors SQS NumberOfMessagesSent"
  alarm_actions       = var.actions_alarm

  dimensions = {
    QueueName = aws_sqs_queue.queue[count.index].name
  }
}

resource "aws_cloudwatch_metric_alarm" "approximatenumberofmessagesdelayed_too_high" {
  count               = var.alarm_enabled ? 1 : 0
  alarm_name          = "${aws_sqs_queue.queue[count.index].name}-High-ApproximateNumberOfMessagesDelayed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "ApproximateNumberOfMessagesDelayed"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Average"
  threshold           = var.ApproximateNumberOfMessagesDelayed
  alarm_description   = "This metric monitors SQS ApproximateNumberOfMessagesDelayed"
  alarm_actions       = var.actions_alarm

  dimensions = {
    QueueName = aws_sqs_queue.queue[count.index].name
  }
}

resource "aws_cloudwatch_metric_alarm" "approximatenumberofmessagesvisible_too_high" {
  count               = var.alarm_enabled ? 1 : 0
  alarm_name          = "${aws_sqs_queue.queue[count.index].name}-High-ApproximateNumberOfMessagesVisible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Average"
  threshold           = var.ApproximateNumberOfMessagesVisible
  alarm_description   = "This metric monitors SQS ApproximateNumberOfMessagesVisible"
  alarm_actions       = var.actions_alarm

  dimensions = {
    QueueName = aws_sqs_queue.queue[count.index].name
  }
}

resource "aws_cloudwatch_metric_alarm" "oldest_message_age_too_high" {
  count               = var.alarm_enabled ? 1 : 0
  alarm_name          = "${aws_sqs_queue.queue[count.index].name}-High-ApproximateAgeOfOldestMessage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Maximum"
  threshold           = var.oldest_message_age_threshold
  alarm_description   = "Alert when the oldest SQS message exceeds the age threshold, indicating a consumer backlog"
  alarm_actions       = var.actions_alarm
  ok_actions          = var.actions_ok

  dimensions = {
    QueueName = aws_sqs_queue.queue[count.index].name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages_too_high" {
  count               = var.alarm_enabled && var.create_dlq ? 1 : 0
  alarm_name          = "${aws_sqs_queue.dlq_queue[count.index].name}-High-ApproximateNumberOfMessagesVisible"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.evaluation_period
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.statistic_period
  statistic           = "Sum"
  threshold           = var.dlq_messages_threshold
  alarm_description   = "Alert when messages appear in the Dead Letter Queue, indicating repeated processing failures"
  alarm_actions       = var.actions_alarm
  ok_actions          = var.actions_ok

  dimensions = {
    QueueName = aws_sqs_queue.dlq_queue[count.index].name
  }
}
