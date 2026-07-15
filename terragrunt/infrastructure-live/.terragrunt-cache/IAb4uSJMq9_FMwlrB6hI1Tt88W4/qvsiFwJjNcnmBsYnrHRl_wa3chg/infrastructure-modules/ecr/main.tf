module "iam_label" {
  source    = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.25.0"
  namespace = var.namespace
  stage     = var.stage

  tags = {
    Namespace  = var.namespace
    Stage      = var.stage
    Team       = "DevOps"
    Org        = "SystemEngg"
    Service    = var.service
    Attributes = var.attributes
  }
}


resource "aws_ecr_repository" "repo_create" {
  for_each             = var.repositories
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = var.image_scaning_enable
  }
  tags = merge(module.iam_label.tags, {
    Name = each.key
  })
}

data "aws_iam_policy_document" "repo_policy_doc" {
  for_each = var.repositories
  statement {
    sid    = "AllowCrossAccountPushAndPull"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:DeleteRepository",
      "ecr:BatchDeleteImage",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy"
    ]
    principals {
      identifiers = each.value
      type        = "AWS"
    }

  }
}

resource "aws_ecr_repository_policy" "repo_create_policy" {
  for_each   = var.repositories
  repository = each.key
  policy     = data.aws_iam_policy_document.repo_policy_doc[each.key].json
  depends_on = [aws_ecr_repository.repo_create]
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  for_each   = var.enable_expiry ? var.repositories : {}
  policy     = jsonencode({ rules = var.expiry_policy })
  repository = aws_ecr_repository.repo_create[each.key].name
  depends_on = [aws_ecr_repository.repo_create]
}

resource "aws_ecr_registry_scanning_configuration" "configuration" {
  scan_type = "ENHANCED"

  dynamic "rule" {
    for_each = var.scanning_rules
    content {
      scan_frequency = rule.value.scan_frequency
      repository_filter {
        filter      = rule.value.filter
        filter_type = rule.value.filter_type
      }
    }
  }
}