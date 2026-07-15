resource "null_resource" "notification" {
  count = var.enable_notifications ? 1 : 0
  provisioner "local-exec" {
    command = "/bin/bash notification.sh"

    environment = {
      topic_arn = var.sns_topic_arn
    }
  }
  depends_on = [aws_eks_node_group.node_groups]
}