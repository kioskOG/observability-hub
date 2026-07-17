include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../..//infrastructure-modules/eks/"
}

locals {
  common_vars = yamldecode(file("${get_terragrunt_dir()}/../common.yaml"))
  common_tags = {
    Env : "dev",
    Owner : "systemengg",
    Pod : "DevOps"
    Project : "millenniumfalcon",
  }
  worker_tags = {
    "kubernetes.io/cluster/millenniumfalcon" : "owned"
  }
  alias = "eks"
}

inputs = {
  region      = local.common_vars["aws_region"]
  cluster_name                     = "millenniumfalcon"
  eks_cluster_version              = "1.35"
  vpc_id                           = local.common_vars["vpc_id"]
  subnets                          = concat(local.common_vars["private_subnets"], local.common_vars["public_subnets"])
  tags                             = local.common_tags
  endpoint_private                 = true
  endpoint_public                  = true
  enabled_cluster_log_types        = []
  key_name                         = "millenniumfalcon-eks"
  userdatafile                     = true
  max_unavailable_percentage_nodes = 10 ## Need to change this once we go LIVE
  enable_audit_eks_ami             = false
  enable_bottlerocket_ami          = false
  manage_aws_auth                  = false
  authentication_mode              = "API"

  cluster_security_group_additional_rules = {
    ingress_cluster_443_from_infra_eks = {
      description = "Allow access to cluster API from Infra EKS server"
      protocol    = "tcp"
      port        = 443
      type        = "ingress"
      cidr_blocks = ["10.36.0.0/16"]
    }
    ingress_cluster_443_from_vpn = {
      description              = "Allow access to cluster API from netbird vpn client"
      protocol                 = "tcp"
      port                     = 443
      type                     = "ingress"
      source_security_group_id = null
      cidr_blocks              = ["14.102.78.0/24"]
    }   
  }
  worker_security_group_additional_rules = {
    ingress_worker_443_from_vpn = {
      from_port                = 0
      to_port                  = 0
      description              = "Allow access to worker nodes from netbird vpn client"
      type                     = "ingress"
      protocol                 = "tcp"
      source_security_group_id = null
      self                     = null
      cidr_blocks              = ["14.102.78.0/24", "10.36.0.0/16"]
      ipv6_cidr_blocks         = null
    }
  }

  bootstrap_admin_role_arn = "arn:aws:iam::547580490325:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministrator_90ebffa4e54cb179"

  map_roles = [
    {
      rolearn  = "arn:aws:iam::547580490325:role/eks-millenniumfalcon-nodegroup-role"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:nodes","system:bootstrappers"]
    },
    # {
    #   rolearn  = "arn:aws:iam::450680052277:role/millenniumfalcon"
    #   username = "system:node:{{EC2PrivateDNSName}}"
    #   groups   = ["system:masters","system:bootstrappers"]
    # },
    # {
    #   rolearn  = "arn:aws:iam::547580490325:role/kiosk-infra-atlantis"
    #   username = "system:admin"
    #   groups   = ["system:masters"]
    # },
    # {
    #   rolearn  = "arn:aws:iam::547580490325:role/kiosk-terraform"
    #   username = "system:admin"
    #   groups   = ["system:masters"]
    # }
  ]

  map_users = [
    # {
    #   userarn  = "arn:aws:iam::450680052277:user/conman"
    #   username = "conman"
    #   groups   = ["system:masters","system:bootstrappers"]
    # }
  ]

  access_entries = [
  # cluster admins (humans/bots)
  {
    principal_arn = "arn:aws:iam::547580490325:role/shorturl-github-cicd-dev"
    type          = "STANDARD"
    policy_key    = "cluster_admin"
    scope_type    = "cluster"
  },

  # team-a namespace admins
  # {
  #   principal_arn = "arn:aws:iam::123456789012:role/team-a"
  #   type          = "STANDARD"
  #   policy_key    = "admin"
  #   scope_type    = "namespace"
  #   namespaces    = ["team-a"]
  # },

  # read-only viewers at cluster scope
  # {
  #   principal_arn = "arn:aws:iam::123456789012:role/sre-viewers"
  #   type          = "STANDARD"
  #   policy_key    = "view"
  #   scope_type    = "cluster"
  # },

  # node role for self-managed/Karpenter (if applicable)
  {
    principal_arn = "arn:aws:iam::547580490325:role/eks-millenniumfalcon-nodegroup-role"
    type          = "EC2_LINUX"
    policy_key    = "view"
    scope_type    = "cluster"
  }
]


  cluster_addons = {
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = "v1.20.1-eksbuild.3"
      preserve          = true
    }
    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      addon_version            = "v1.41.0-eksbuild.1"
      service_account_role_arn = "arn:aws:iam::547580490325:role/eks-millenniumfalcon-nodegroup-role"
    }
    coredns = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = "v1.12.1-eksbuild.2"
      preserve          = true
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
      addon_version     = "v1.35.3-eksbuild.2"
    }
  }

  ### Node Group
  create_node_group = true
  node_groups = {
    "wazuh" = {
      subnets          = local.common_vars["private_subnets"]
      instance_type    = ["m5.xlarge"]
      desired_capacity = 2
      max_capacity     = 5
      min_capacity     = 1
      capacity_type    = "ON_DEMAND" #"SPOT" , "ON_DEMAND"
      tags             = merge(local.common_tags, local.worker_tags)
      kubeargs         = "--node-labels=isolation=private,lifecycle=normal,managed=false --kube-reserved cpu=300m,memory=0.3Gi,ephemeral-storage=1Gi --system-reserved cpu=300m,memory=0.2Gi,ephemeral-storage=1Gi --eviction-hard memory.available<200Mi,nodefs.available<10% --cpu-cfs-quota=false --registry-qps=10"
      volume_size      = 20
      # image_id         = "ami-002293d4b9f6c80d3"
      audit_ami = false
      bottlerocket_ami = false
    }
  }
#  custom_policy = <<EOF
#{
#    "Version": "2012-10-17",
#    "Statement": [
#        {
#            "Sid": "AllowKmsDecrypt",
#            "Effect": "Allow",
#            "Action": "kms:Decrypt",
#            "Resource": "arn:aws:kms:ap-south-1:530442485024:key/77378551-edad-4e35-aa6a-c636c8fba257"
#        },
#        {
#            "Sid": "AllowSES",
#            "Effect": "Allow",
#            "Action": "ses:*",
#			      "Resource": "*"
#        }
#    ]
#}
#EOF
}

# tested




# Note

# when u see an error on apply like below

#   Enter a value: yes

# kubernetes_config_map_v1_data.aws_auth: Creating...
# kubernetes_config_map.aws_auth: Creating...
# kubernetes_config_map_v1_data.aws_auth: Creation complete after 1s [id=kube-system/aws-auth]

# Error: configmaps "aws-auth" already exists

#   with kubernetes_config_map.aws_auth,
#   on aws_auth.tf line 12, in resource "kubernetes_config_map" "aws_auth":
#   12: resource "kubernetes_config_map" "aws_auth" {

# ERRO[0022] 1 error occurred:
#         * exit status 1


# solution:-

# aws eks list-access-entries --cluster-name millenniumfalcon | jq

# terraform import kubernetes_config_map.aws_auth kube-system/aws-auth

# terragrunt state list | grep aws_eks_access_entry
# terragrunt import \
# 'aws_eks_access_entry.this["arn:aws:iam::547580490325:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministrator_90ebffa4e54cb179"]' \
# 'millenniumfalcon:arn:aws:iam::547580490325:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministrator_90ebffa4e54cb179'



# update the ebs-csi-controller service account iam role trust relationship
# {
#      "Effect": "Allow",
#      "Principal": {
#        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
#      },
#      "Action": "sts:AssumeRoleWithWebIdentity",
#      "Condition": {
#        "StringEquals": {
#          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
#          "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:aud": "sts.amazonaws.com"
#        }
#      }
#    }
