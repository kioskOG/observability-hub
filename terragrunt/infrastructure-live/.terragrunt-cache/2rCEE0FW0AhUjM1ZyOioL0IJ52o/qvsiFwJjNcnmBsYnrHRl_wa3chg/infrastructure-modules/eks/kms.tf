resource "aws_kms_key" "eks_cluster" {
  count                   = var.create_kms ? 1 : 0
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  policy                  = var.policy
  tags = {
    "Provisioner" = "Terraform"
  }
  description              = var.description
  key_usage                = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  multi_region             = var.multi_region
}

resource "aws_kms_alias" "default" {
  count         = var.create_kms ? 1 : 0
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.eks_cluster[0].id
}
