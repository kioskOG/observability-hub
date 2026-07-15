# AWS EKS

This terraform module will helps user to:

- Create EKS Cluster,
- Flexible enough to provide Node group and fargate as well.
- CoreDNS pods to be deployed on a particular node for PCI DSS purpose.
- Custom OIDC support as well.

## Variable information

| Name | Description | Type | Default | Required | Depends-On|
|------|-------------|------|---------|----------|-----------|
|region|AWS region|`string`|-|yes|-|
|cluster_name|Name for the cluster|`string`|-|yes|-|
|subnets|A list of subnets for worker nodes|`list(string)`|-|yes|-|
|eks_cluster_version|Kubernetes cluster version in EKS|`string`|-|yes|-|
|scale_min_size|Minimum count of workers|`number`|2|yes|-|
|scale_max_size|Maximum count of workers|`number`|5|yes|-|
|scale_desired_size|Desired count of workers|`number`|3|yes|-|
|config_output_path|kubeconfig output path|`string`|kubeconfig|no|-|
|kubeconfig_name|Name of kubeconfig file|`string`|kubeconfig|no|-|
|endpoint_private|Make EKS endpoint private|`bool`|true|no|-|
|public_access_cidrs|List of public access CIDRs|`list`|[]|no|-|
|endpoint_public|Make EKS endpoint public|`bool`|false|yes|-|
|vpc_id|VPC ID for cluster|`string`|-|yes|-|
|enabled_cluster_log_types|List of the desired control plane logging to enable|`list(string)`|["api", "audit", "authenticator", "controllerManager", "scheduler"]|no|-|
|create_encryption_config|Provide whether to create encryption config or not|`bool`|true|no|-|
|cluster_encryption_config|Configuration block with encryption configuration for the cluster|`map(object)`| "encrypt" = {resources = ["secrets"]}|no|create_encryption_config|
|securitygroups|list of secondary SGs ID which needs to be attached with Cluster|`list(string)`|[]|no|-|
|node_groups|Paramters which are required for creating node group|`any`|-|yes|-|
|create_node_group|Create node group or not|`bool`|false|yes|-|
|force_update_version|Force version update if existing pods are unable to be drained due to a pod disruption budget issue|`bool`|false|no|-|
|tags|Tags to add on all of the resources|`map(string)`|{}|yes|-|
|encrypted|Provide the encryption for EBS|`bool`|true|no|-|
|userdata_path|Provide the userdata file path|`string`|-|no|userdatafile|
|userdatafile|If true then provide variable userdata_path with the correct file path|`bool`|false|no|-|
|enable_bottlerocket_ami|Bottlerocket AMI for node group|`bool`|true|no|-|
|search_audit_eks_ami|Custom AMI for node group|`bool`|true|no|-|
|max_unavailable_nodes|Desired max number of unavailable worker nodes during node group update|`number`|1|no|max_unavailable_percentage_nodes|
|max_unavailable_percentage_nodes|Desired max percentage of unavailable worker nodes during node group update in %|`number`|null|no|-|
|audit_ami|Node group to use Audit AMI [Priority of AMIs : audit_ami > custom ami `image_id` if provided else `eks default` ami will be taken]|`bool`|false|no|-|
|eks_audit_ami_owner|Audit AMI Owner which is Audit account ID|`string`|643652920681|no|audit_ami|
|eks_bottlerocket_ami_owner|Bottlerocket AMI Owner|`string`|040063162771|no|enable_bottlerocket_ami|
|fargate_profiles|Paramters which are required for creating fargate profile|`map(object)`|{}|yes|-|
|account_id|Provide the account ID for fargate IAM Role|`string`|""|yes|-|
|create_fargate_role|Provide value to create role for fargate|`bool`|false|yes|-|
|deletion_window_in_days|Duration in days after which the key is deleted after destruction of the resource|`number`|7|yes|create_kms|
|enable_key_rotation|Specifies whether key rotation is enabled|`bool`|true|yes|create_kms|
|description|The description of the key as viewed in AWS console|`string`|"For EKS CLuster"|yes|create_kms|
|policy|A valid KMS policy JSON document|`string`|""|yes|create_kms|
|key_usage|Specifies the intended use of the key. Valid values: `ENCRYPT_DECRYPT` or `SIGN_VERIFY`|`string`|"ENCRYPT_DECRYPT"|yes|create_kms|
|customer_master_key_spec|Specifies whether the key contains a symmetric key or an asymmetric key pair and the encryption algorithms or signing algorithms that the key supports. Valid values: `SYMMETRIC_DEFAULT`, `RSA_2048`, `RSA_3072`, `RSA_4096`, `ECC_NIST_P256`, `ECC_NIST_P384`, `ECC_NIST_P521`, or `ECC_SECG_P256K1`|`string`|"SYMMETRIC_DEFAULT"|yes|create_kms|
|multi_region|Indicates whether the KMS key is a multi-Region (true) or regional (false) key|`bool`|false|no|create_kms|
|alias|Provide the alias for the KMS|`string`|"EKS"|yes|create_kms|
|create_kms|If true it will create KMS for EKS|`bool`|true|no|-|
|kms_arn|Provide custom KMS ARN for Cluster|`string`|""|no|-|
|create_key_pair|Controls if key pair should be created|`bool`|true|no|-|
|key_name|The name for the key pair|`string`|null|yes|create_key_pair|
|addon_create_vpc_cni|-|`bool`|true|yes|-|
|addon_vpc_cni_version|-|`string`|"v1.11.2-eksbuild.1"|no|addon_create_vpc_cni|
|vpc_cni_version|-|`string`|"default"|no|-|
|addon_create_kube_proxy|-|`bool`|true|yes|-|
|addon_kube_proxy_version|-|`string`|"v1.22.6-eksbuild.1"|no|-|
|kube_proxy_version|-|`string`|"default"|no|-|
|addon_create_coredns|-|`bool`|true|yes|-|
|addon_coredns_version|-|`string`|"v1.8.7-eksbuild.1"|no|-|
|coredns_version|-|`string`|"default"|no|-|
|create_lambda_coredns|Create lambda for coredns pod to be deployed in particular node|`bool`|false|-|
|lambda_subnets|A list of subnets for worker nodes|`list(string)`|[]|yes|create_lambda_coredns|
|coredns_toleration_value|Toleration value for coredns in lambda|`string`|"coresystem"|yes|create_lambda_coredns|
|coredns_nodeSelector_value|NodeSelector value for coredns in lambda|`string`|"coresystem"|yes|create_lambda_coredns|
|map_roles|Granting access of cluster to roles|`any`|-|yes|-|
|custom_oidc_thumbprints|Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)|`list(string)`|[]|yes|-|
|sns_topic_arn|ASG SNS Topic arn|`string`|-|no|-|

## Usage

```hcl
  cluster_name                     = "<product>-dev"
  eks_cluster_version              = "1.22"
  vpc_id                           = "vpc-xxxxxxxxxxxxxx"
  subnets                          = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
  lambda_subnets                   = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
  tags                             = local.common_tags
  endpoint_private                 = true
  endpoint_public                  = true
  enabled_cluster_log_types        = []
  key_name                         = "<product>-dev"
  userdatafile                     = true
  userdata_path                    = "userdata.sh"
  max_unavailable_percentage_nodes = 100
  map_roles = [
    {
      rolearn  = "arn:aws:iam::xxxxxxxxxxxxx:role/<name>"
      username = "system:admin"
      groups   = ["system:masters"]
    }
  ]

  ############################
  ### CoreDNS NodeSelector ###
  ############################
  create_lambda_coredns      = true
  coredns_nodeSelector_value = "coresystem"
  coredns_toleration_value   = "coresystem"

  #################
  ###Node Group ###
  #################
  create_node_group = true
  node_groups = {
    "cde" = {
      subnets          = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
      instance_type    = ["t3.medium", "t3.small"]
      desired_capacity = 0
      max_capacity     = 1
      min_capacity     = 0
      capacity_type    = "SPOT"
      tags             = merge(local.common_tags, local.worker_tags)
      kubeargs         = "--node-labels=node.kubernetes.io/env=cde,lifecycle=spot,managed=false --register-with-taints=appType=cde:NoSchedule --kube-reserved memory=0.3Gi,ephemeral-storage=1Gi --system-reserved memory=0.2Gi,ephemeral-storage=1Gi --eviction-hard memory.available<200Mi,nodefs.available<10% --cpu-cfs-quota=false --registry-qps=10"
      volume_size      = 90
      image_id         = "ami-xxxxxxxxxxxxx"
    }
    "noncde" = {
      subnets          = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
      instance_type    = ["t3.medium", "t3.small"]
      desired_capacity = 0
      max_capacity     = 1
      min_capacity     = 0
      capacity_type    = "SPOT"
      tags             = merge(local.common_tags, local.worker_tags)
      kubeargs         = "--node-labels=node.kubernetes.io/env=noncde,lifecycle=spot,managed=false --register-with-taints=appType=noncde:NoSchedule --kube-reserved memory=0.3Gi,ephemeral-storage=1Gi --system-reserved memory=0.2Gi,ephemeral-storage=1Gi --eviction-hard memory.available<200Mi,nodefs.available<10% --cpu-cfs-quota=false --registry-qps=10"
      volume_size      = 90
      image_id         = "ami-xxxxxxxxxxxxx"
    }
    "connected" = {
      subnets          = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
      instance_type    = ["t3.medium", "t3.small"]
      desired_capacity = 0
      max_capacity     = 1
      min_capacity     = 0
      capacity_type    = "SPOT"
      tags             = merge(local.common_tags, local.worker_tags)
      kubeargs         = "--node-labels=node.kubernetes.io/env=connected,lifecycle=spot,managed=false --register-with-taints=appType=connected:NoSchedule --kube-reserved memory=0.3Gi,ephemeral-storage=1Gi --system-reserved memory=0.2Gi,ephemeral-storage=1Gi --eviction-hard memory.available<200Mi,nodefs.available<10% --cpu-cfs-quota=false --registry-qps=10"
      volume_size      = 90
      image_id         = "ami-xxxxxxxxxxxxx"
    }
    "coresystem" = {
      subnets          = ["subnet-xxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxx"]
      instance_type    = ["t3.medium", "t3.small", "t3.micro"]
      desired_capacity = 0
      max_capacity     = 1
      min_capacity     = 0
      capacity_type    = "SPOT"
      tags             = merge(local.common_tags, local.worker_tags)
      kubeargs         = "--node-labels=node.kubernetes.io/env=coresystem,lifecycle=spot,managed=false --register-with-taints=appType=coresystem:NoSchedule --kube-reserved memory=0.3Gi,ephemeral-storage=1Gi --system-reserved memory=0.2Gi,ephemeral-storage=1Gi --eviction-hard memory.available<200Mi,nodefs.available<10% --cpu-cfs-quota=false --registry-qps=10"
      volume_size      = 90
      image_id         = "ami-xxxxxxxxxxxxx"
      security_group   = {
        ingress = [
          {
            from_port                = 0
            to_port                  = 0
            description              = "Allow access to self"
            protocol                 = -1
            source_security_group_id = null
            self                     = true
            cidr_blocks              = null
            ipv6_cidr_blocks         = null
          }
        ]
        egress = [
          {
            from_port                = 0
            to_port                  = 0
            description              = "Allow access to self"
            type                     = "ingress"
            protocol                 = -1
            source_security_group_id = null
            self                     = null
            cidr_blocks              = ["0.0.0.0/0"]
            ipv6_cidr_blocks         = ["::/0"]
          }
        ]
      }
    }
  }
}

```
