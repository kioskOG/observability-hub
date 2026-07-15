resource "aws_eks_node_group" "node_groups" {
  for_each     = var.create_node_group ? var.node_groups : null
  cluster_name = aws_eks_cluster.eks_cluster.name
  tags = merge(
    {
      Name = format("%s-node_group", substr(each.key, 0, 20))
    },
    {
      "Provisioner" = "Terraform"
    },
    each.value.tags
  )
  node_group_name_prefix = "${substr(each.key, 0, 20)}-"
  node_role_arn          = aws_iam_role.node_group_role[0].arn
  subnet_ids             = each.value.subnets
  instance_types         = each.value.instance_type
  capacity_type          = each.value.capacity_type
  force_update_version   = var.force_update_version

  launch_template {
    id      = aws_launch_template.launch_template[each.key].id
    version = aws_launch_template.launch_template[each.key].latest_version
  }

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_capacity
    min_size     = each.value.min_capacity
  }

  // INFO -  Use either max_unavailable or max_unavailable_percentage, cann't use both options
  update_config {
    max_unavailable            = var.max_unavailable_percentage_nodes == null ? var.max_unavailable_nodes : null
    max_unavailable_percentage = var.max_unavailable_percentage_nodes
    // TOFIX - Right now this value applies on all node groups,
    // need to fix this to get this as input for each node group.

  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false
    ignore_changes        = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}


resource "aws_iam_role" "node_group_role" {
  count = var.create_node_group ? 1 : 0
  name  = "eks-${var.cluster_name}-nodegroup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = merge(
    {
      Name = format("%s-node_group_iam_role", var.cluster_name)
    },
    {
      "Provisioner" = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2FullAccess" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2RoleforSSM" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2RoleforSSM" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_role_policy_attachment" "node-AmazonInspector2ManagedCispolicy" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonInspector2ManagedCisPolicy"
  role       = aws_iam_role.node_group_role[0].name
}

resource "aws_iam_policy" "custom-policy" {
  count  = var.create_node_group && var.custom_policy != null ? 1 : 0
  name   = "${aws_eks_cluster.eks_cluster.name}-eks-node-custom-policy"
  policy = var.custom_policy
}

resource "aws_iam_role_policy_attachment" "node-custom-policy" {
  count      = var.create_node_group && var.custom_policy != null ? 1 : 0
  policy_arn = aws_iam_policy.custom-policy[0].arn
  role       = aws_iam_role.node_group_role[0].name
}

###################################
### Launch Template for workers ###
###################################

resource "aws_launch_template" "launch_template" {
  for_each = var.node_groups
  name     = "${each.key}-${aws_eks_cluster.eks_cluster.name}-LaunchTemplate"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = lookup(each.value, "volume_size", 50)
      encrypted   = true
      volume_type = "gp3"
    }
  }

  #image_id = try(each.value.audit_ami, null) == true ? data.aws_ami.eks_audit_ami[0].image_id : lookup(each.value, "image_id", data.aws_ami.eks_default.image_id)
  image_id = try(each.value.audit_ami, null) == true ? data.aws_ami.eks_audit_ami[0].image_id : try(each.value.bottlerocket_ami, null) == true ? data.aws_ami.eks_bottlerocket_ami[0].image_id : lookup(each.value, "image_id", data.aws_ami.eks_default.image_id)
  key_name = aws_key_pair.eks_cluster_key[0].id
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  vpc_security_group_ids = compact([aws_security_group.worker_sg.id, try(aws_security_group.secondary_worker_sg[each.key].id, "")])
  monitoring {
    enabled = true
  }

  # user_data = try(each.value.bottlerocket_ami, null) == true ? base64encode(data.template_file.bottlerocket_userdata[each.key].rendered) : base64encode(data.template_file.userdata[each.key].rendered)
  user_data = base64encode(data.template_file.userdata[each.key].rendered)

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      {
        Name = format("%s-%s-${each.key}", "eks", var.cluster_name)
      },
      {
        "Provisioner" = "Terraform"
      },
      var.tags
    )
  }
}

############################################
###  Default Security Group for workers  ###
############################################

resource "aws_security_group" "worker_sg" {
  name        = "${aws_eks_cluster.eks_cluster.name}-eks-worker-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${aws_eks_cluster.eks_cluster.name}-eks-worker-sg"
  }
}

##################################################
###  Default Security Group Rules for workers  ###
##################################################

resource "aws_security_group_rule" "worker_sg_rules" {
  # for_each                 = local.sg_worker_rules
  for_each                 = { for k, v in merge(local.sg_worker_rules, var.worker_security_group_additional_rules) : k => v }
  description              = each.value.description
  type                     = each.value.type
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  security_group_id        = aws_security_group.worker_sg.id
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self
  cidr_blocks              = each.value.cidr_blocks
  ipv6_cidr_blocks         = each.value.ipv6_cidr_blocks
}

####################################################
###  Secondary Security Group Rules for workers  ###
####################################################

resource "aws_security_group" "secondary_worker_sg" {
  for_each    = toset(local.security_group)
  name        = "${aws_eks_cluster.eks_cluster.name}-${each.key}-eks-worker-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.node_groups[each.key]["security_group"]["ingress"]
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      description      = ingress.value.description
      protocol         = ingress.value.protocol
      self             = ingress.value.self
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
    }
  }
  dynamic "egress" {
    for_each = var.node_groups[each.key]["security_group"]["egress"]
    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      description      = egress.value.description
      protocol         = egress.value.protocol
      self             = egress.value.self
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }

}

####################
###  Data Block  ###
####################

data "template_file" "userdata" {
  for_each = toset(local.node_group_userdata)
  # template = var.userdatafile == false ? file("${path.module}/bootstrap.sh") : format("%s%s", file("${path.module}/bootstrap.sh"), file("${path.module}/${var.userdata_path}"))
  # If var.use_nodeconfig is true → use nodeconfig.yaml.tpl
  # Else if var.userdatafile is false → use bootstrap.sh
  # Else → concatenate bootstrap + custom user data file
  template = var.use_nodeconfig ? file("${path.module}/templates/nodeconfig.yaml.tpl") : (var.userdatafile == false ? file("${path.module}/bootstrap.sh") : format("%s%s", file("${path.module}/bootstrap.sh"), file("${path.module}/${var.userdata_path}")))

  vars = {
    CLUSTER_NAME         = var.cluster_name
    B64_CLUSTER_CA       = aws_eks_cluster.eks_cluster.certificate_authority.0.data
    API_SERVER_URL       = aws_eks_cluster.eks_cluster.endpoint
    KUBELET_ARGS         = var.node_groups[each.key].kubeargs
    CLUSTER_SERVICE_CIDR = var.cluster_service_cidr
  }
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

########################################
###  Data Block for Bottlerocket AMI ###
########################################

data "template_file" "bottlerocket_userdata" {
  for_each = toset(local.bottlerocket_userdata)
  #template = each.value.userdatafile == false ? file("${path.module}/bootstrap.sh") : format("%s%s", file("${path.module}/bootstrap.sh"), file("${path.module}/${each.value.userdata_path}"))
  template = file("${path.module}/templates/bottlerocket_custom.tpl")
  vars = {
    cluster_name         = var.cluster_name
    cluster_auth_base64  = aws_eks_cluster.eks_cluster.certificate_authority.0.data
    cluster_endpoint     = aws_eks_cluster.eks_cluster.endpoint
    bootstrap_extra_args = var.node_groups[each.key].bootstrap_extra_args
  }
}

###########################
##### EKS Default AMI #####
###########################

data "aws_ami" "eks_default" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-al2023-x86_64-standard-${var.eks_cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["amazon"]
}

######################
##### Audit AMI ######
######################

data "aws_ami" "eks_audit_ami" {
  count = var.enable_audit_eks_ami ? 1 : 0

  filter {
    name   = "name"
    values = ["salaryse-audit-custom-ami-amazon-eks-node-${var.eks_cluster_version}-*"]
  }

  most_recent = true
  owners      = ["${var.eks_audit_ami_owner}"]
}

#############################
##### Bottlerocket AMI ######
#############################

data "aws_ami" "eks_bottlerocket_ami" {
  count = var.enable_bottlerocket_ami ? 1 : 0

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${var.eks_cluster_version}-x86_64-*"]
  }

  most_recent = true
  owners      = ["${var.eks_bottlerocket_ami_owner}"]
}

###############
### SSH KEY ###
###############

resource "tls_private_key" "default" {
  algorithm = "RSA"
}

resource "aws_key_pair" "eks_cluster_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = tls_private_key.default.public_key_openssh
  tags       = var.tags

}

resource "local_sensitive_file" "private_key" {
  count           = var.download_key_pair_locally ? 1 : 0
  content         = tls_private_key.default.private_key_pem
  filename        = "/tmp/${var.key_name}.pem"
  file_permission = "0600"
}


data "aws_autoscaling_groups" "this" {
  filter {
    name   = "tag:k8s.io/cluster-autoscaler/enabled"
    values = ["true"]
  }
  filter {
    name   = "tag:k8s.io/cluster-autoscaler/${var.cluster_name}"
    values = ["owned"]
  }
}

resource "null_resource" "nodegroup_asg_azbalance_disable" {
  # triggers = {
  #   suspend_azrebalance = var.suspend_azrebalance == true ? var.suspend_azrebalance :
  # }
  for_each = var.suspend_azrebalance == true ? toset(data.aws_autoscaling_groups.this.names) : []

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<EOF
set -e
aws autoscaling suspend-processes \
  --region ${var.region} \
  --auto-scaling-group-name ${each.key} \
  --scaling-processes AZRebalance
EOF
  }
}
