resource "aws_eks_cluster" "eks_cluster" {
  name                      = var.cluster_name
  enabled_cluster_log_types = var.enabled_cluster_log_types
  role_arn                  = aws_iam_role.cluster_role.arn
  version                   = var.eks_cluster_version

  dynamic "encryption_config" {
    for_each = var.create_encryption_config ? var.cluster_encryption_config : {}

    content {
      provider {
        key_arn = var.create_kms == true ? aws_kms_key.eks_cluster[0].arn : var.kms_arn
      }
      resources = encryption_config.value.resources
    }
  }

  tags = merge(
    {
      Name = format("%s-cluster", var.cluster_name)
    },
    {
      "Provisioner" = "Terraform"
    },
    var.tags
  )
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKSServicePolicy,
  ]

  vpc_config {
    subnet_ids              = var.subnets
    endpoint_private_access = var.endpoint_private
    endpoint_public_access  = var.endpoint_public
    public_access_cidrs     = var.public_access_cidrs
    # security_group_ids      = ["sg-0fe83099ce9ed0b1e"]
    # security_group_ids      = var.security_group_enabled == false ? null : compact([aws_security_group.additionalsg[0].id])
    security_group_ids = var.securitygroups == [] ? null : var.securitygroups
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.cluster_service_cidr # 👈 custom Service CIDR
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }
}

resource "aws_iam_role" "cluster_role" {
  name = var.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  tags = merge(
    {
      Name = format("%s-cluster_iam_role", var.cluster_name)
    },
    {
      "Provisioner" = "Terraform"
    },
    var.tags
  )
}

#####################
### Cluster Roles ###
#####################

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster_role.name
}

###################
### Subnet Tags ###
###################s

resource "aws_ec2_tag" "add_tags_into_subnet" {
  count       = length(var.subnets)
  resource_id = var.subnets[count.index]
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

########################
### Cluster SG Rules ###
########################

resource "aws_security_group_rule" "clustersgrules" {
  # for_each                 = local.sg_cluster_rules
  for_each    = { for k, v in merge(local.sg_cluster_rules, var.cluster_security_group_additional_rules) : k => v }
  type        = each.value.type
  from_port   = each.value.port
  to_port     = each.value.port
  protocol    = each.value.protocol
  description = each.value.description
  # source_security_group_id = aws_security_group.worker_sg.id
  source_security_group_id = lookup(each.value, "source_security_group_id", null) != null ? lookup(each.value, "source_security_group_id") : lookup(each.value, "cidr_blocks", null) != null ? null : aws_security_group.worker_sg.id
  security_group_id        = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
}

# resource "aws_security_group" "additionalsg" {
#   count = var.security_group_enabled ? 1 : 0
#   name        = "${var.cluster_name}-additional-sg"
#   description = "Additional security group for EKS cluster"
#   vpc_id      = var.vpc_id
#   tags = {
#     Name = "${var.cluster_name}-additional-sg"
#   }
# }

# resource "aws_security_group_rule" "additionalsgrules" {
#   # for_each                 = local.sg_addition_rules
#   for_each = { for k, v in merge(local.sg_addition_rules, var.security_group_additional_rules) : k => v if var.security_group_enabled }
#   type                     = each.value.type
#   from_port                = each.value.port
#   to_port                  = each.value.port
#   protocol                 = each.value.protocol
#   description              = each.value.description
#   security_group_id        = aws_security_group.additionalsg[0].id
#   source_security_group_id = aws_security_group.worker_sg.id
# }