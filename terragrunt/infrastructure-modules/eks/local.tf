locals {
  kubeconfig = templatefile("${path.module}/templates/kubeconfig.tpl", {
    kubeconfig_name     = var.kubeconfig_name
    cluster_name        = var.cluster_name
    endpoint            = aws_eks_cluster.eks_cluster.endpoint
    cluster_auth_base64 = aws_eks_cluster.eks_cluster.certificate_authority[0].data
    cluster_arn         = aws_eks_cluster.eks_cluster.arn
    region              = var.region
  })
  configmap_roles = [
    {
      rolearn  = aws_iam_role.node_group_role[0].arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = tolist(concat(
        [
          "system:bootstrappers",
          "system:nodes",
        ],
      ))
    }
  ]
}

locals {
  sg_worker_rules = {
    rule1 = {
      from_port                = 443
      to_port                  = 443
      description              = "Cluster Default Rules"
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule2 = {
      from_port                = 10250
      to_port                  = 10250
      description              = "Allow Kubelet service from EKS control plane sg."
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule3 = {
      from_port                = 53
      to_port                  = 53
      description              = "Allow CoreDNS service from EKS control plane sg."
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule4 = {
      from_port                = 53
      to_port                  = 53
      description              = "Allow CoreDNS service from EKScontrol plane sg."
      type                     = "ingress"
      protocol                 = "udp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule5 = {
      from_port                = 9443
      to_port                  = 9443
      description              = "Cluster Default Rules"
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule6 = {
      from_port                = 4443
      to_port                  = 4443
      description              = "Allow metric server from EKS control plane sg."
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule7 = {
      from_port                = 0
      to_port                  = 0
      description              = "Allow access to self, this for applications to talk to each other in same cluster"
      type                     = "ingress"
      protocol                 = -1
      source_security_group_id = null
      self                     = true
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule8 = {
      from_port                = 0
      to_port                  = 65535
      description              = "Allow outbound access for self on TCP Protocol."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = true
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule9 = {
      from_port                = 53
      to_port                  = 53
      description              = "Allow outbound access for DNS on UDP Protocol."
      type                     = "egress"
      protocol                 = "udp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = [data.aws_vpc.vpc.cidr_block]
      ipv6_cidr_blocks         = null
    },
    rule10 = {
      from_port                = 53
      to_port                  = 53
      description              = "Allow outbound access for DNS on TCP Protocol."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = [data.aws_vpc.vpc.cidr_block]
      ipv6_cidr_blocks         = null
    },
    rule11 = {
      from_port                = 443
      to_port                  = 443
      description              = "Allow outbound access for HTTPS."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = null
    },
    rule12 = {
      from_port                = 443
      to_port                  = 443
      description              = "Allow outbound access for master node for HTTPS."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule13 = {
      from_port                = 10250
      to_port                  = 10250
      description              = "Allow outbound access for master node for Kubelet API."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
      self                     = null
      cidr_blocks              = null
      ipv6_cidr_blocks         = null
    },
    rule14 = {
      from_port                = 0
      to_port                  = 65535
      description              = "Allow outbound access for TCP for VNet IP."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = [data.aws_vpc.vpc.cidr_block]
      ipv6_cidr_blocks         = null
    },
    rule15 = {
      from_port                = 80
      to_port                  = 80
      description              = "Allow outbound access for HTTP."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = null
    },
    rule16 = {
      from_port                = 587
      to_port                  = 587
      description              = "Allow outbound access for smtp-mail.outlook.com."
      type                     = "egress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = ["0.0.0.0/0"]
      ipv6_cidr_blocks         = null
    },
    # rule9 = {
    #   port                     = 6443
    #   description              = "Allow cert-manager-trust webhook call from EKS control plane sg."
    #   type                     = "ingress"
    #   protocol                 = "tcp"
    #   source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
    #   self                     = null
    #   cidr_blocks              = null
    #   ipv6_cidr_blocks         = null
    # },
    # rule10 = {
    #   port                     = 8443
    #   description              = "Allow Linkerd-injector pod access from EKS control plane sg."
    #   type                     = "ingress"
    #   protocol                 = "tcp"
    #   source_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
    #   self                     = null
    #   cidr_blocks              = null
    #   ipv6_cidr_blocks         = null
    # }
  }
}

locals {
  sg_cluster_rules = {
    # rule1 = {
    #   port     = 443
    #   type     = "ingress"
    #   protocol = "tcp"
    # },
    # rule2 = {
    #   port     = 10250
    #   type     = "ingress"
    #   protocol = "tcp"
    # },
    # rule3 = {
    #   port     = 53
    #   type     = "ingress"
    #   protocol = "tcp"
    # },
    # rule4 = {
    #   port     = 53
    #   type     = "ingress"
    #   protocol = "udp"
    # },
    ingress_cluster_443 = {
      port        = 443
      description = "Allow access to cluster API from Node groups"
      type        = "ingress"
      protocol    = "tcp"
    }
    # ingress_cluster_10250 = {
    #   port     = 10250
    #   description = "Allow Kubelet service from EKS control plane sg."
    #   type     = "ingress"
    #   protocol = "tcp"
    # },
    # ingress_cluster_tcp_53 = {
    #   port     = 53
    #   description = "Allow CoreDNS service from EKS control plane sg."
    #   type     = "ingress"
    #   protocol = "tcp"
    # },
    # ingress_cluster_udp_53 = {
    #   port     = 53
    #   description = "Allow CoreDNS service from EKS control plane sg."
    #   type     = "ingress"
    #   protocol = "udp"
    # }
  }
}

# locals {
#   sg_addition_rules = {
#     ingress_cluster_443 = {
#       port     = 443
#       description = "Allows https to cluster"
#       type     = "ingress"
#       protocol = "tcp"
#     },
#     ingress_cluster_10250 = {
#       port     = 10250
#       description = "Allow Kubelet service from EKS control plane sg."
#       type     = "ingress"
#       protocol = "tcp"
#     },
#     ingress_cluster_tcp_53 = {
#       port     = 53
#       description = "Allow CoreDNS service from EKS control plane sg."
#       type     = "ingress"
#       protocol = "tcp"
#     },
#     ingress_cluster_udp_53 = {
#       port     = 53
#       description = "Allow CoreDNS service from EKS control plane sg."
#       type     = "ingress"
#       protocol = "udp"
#     }
#   }
# }

locals {
  maproles = concat([
    {
      rolearn  = "${aws_iam_role.node_group_role[0].arn}"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }],
    var.map_roles,
    var.map_users
  )
}

locals {
  access_policies = {
    cluster_admin = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    admin         = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    view          = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  }
}


locals {
  security_group        = [for i, k in var.node_groups : i if lookup(k, "security_group", null) != null]
  node_group_userdata   = [for i, j in var.node_groups : i if lookup(j, "kubeargs", null) != null]
  bottlerocket_userdata = [for i, j in var.node_groups : i if lookup(j, "bootstrap_extra_args", null) != null]
}