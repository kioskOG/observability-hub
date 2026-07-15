variable "region" {
  type        = string
  description = "AWS region"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = ""
  type        = string
}

variable "use_nodeconfig" {
  description = "Use YAML NodeConfig style user-data"
  default     = true
  type        = bool
}

variable "cluster_service_cidr" {
  description = "EKS cluster service cidr"
  default     = "172.20.0.0/16"
  type        = string
}

variable "subnets" {
  description = "A list of subnets for worker nodes"
  type        = list(string)
}

variable "eks_cluster_version" {
  description = "Kubernetes cluster version in EKS"
  type        = string
}

variable "scale_min_size" {
  description = "Minimum count of workers"
  type        = number
  default     = 2
}

variable "scale_max_size" {
  description = "Maximum count of workers"
  type        = number
  default     = 5
}

variable "scale_desired_size" {
  description = "Desired count of workers"
  type        = number
  default     = 3
}

variable "config_output_path" {
  description = "kubeconfig output path"
  type        = string
  default     = "kubeconfig"
}

variable "kubeconfig_name" {
  description = "Name of kubeconfig file"
  type        = string
  default     = "kubeconfig"
}

variable "endpoint_private" {
  description = "endpoint private"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of public access CIDRs"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  description = "The authentication mode for the cluster. Valid values are CONFIG_MAP, API or API_AND_CONFIG_MAP"
  type        = string
  default     = "API_AND_CONFIG_MAP" #"CONFIG_MAP"
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Whether or not to bootstrap the access config values to the cluster"
  type        = bool
  default     = false #true
}

variable "manage_aws_auth" {
  description = "Whether to manage the legacy aws-auth ConfigMap"
  type        = bool
  default     = true
}

variable "access_entries" {
  description = <<EOT
List of access entries to grant via EKS Access API.
Each object:
  - principal_arn (string)
  - type          (string)  # STANDARD | EC2_LINUX
  - policy_key    (string)  # key from local.access_policies (below)
  - scope_type    (string)  # cluster | namespace
  - namespaces    (list(string)) # required when scope_type = "namespace"
EOT
  type = list(object({
    principal_arn = string
    type          = string
    policy_key    = string
    scope_type    = string
    namespaces    = optional(list(string), [])
  }))
  default = []
}


variable "endpoint_public" {
  description = "endpoint public"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "enabled_cluster_log_types" {
  description = "List of the desired control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "create_encryption_config" {
  description = "Provide whether to create encryption config or not"
  type        = bool
  default     = true
}

variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster"
  type = map(object({
    resources = list(string)
  }))
  default = {
    "encrypt" = {
      resources = ["secrets"]
    }
  }
}

variable "securitygroups" {
  description = "Provide the list of secondary SGs which needs to be attached with Cluster"
  type        = list(string)
  default     = []
}

#################################
########## Node Group ###########
#################################

variable "node_groups" {
  description = "Paramters which are required for creating node group"
  type        = any
}

variable "create_node_group" {
  description = "Create node group or not"
  type        = bool
  default     = false
}

variable "force_update_version" {
  type        = bool
  description = "Force version update if existing pods are unable to be drained due to a pod disruption budget issue."
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "userdata_path" {
  description = "Provide the userdata file path"
  type        = string
  default     = "userdata.sh"
}

variable "userdatafile" {
  description = "If true then provide variable userdata_path with the correct file path"
  type        = bool
  default     = false
}

variable "enable_audit_eks_ami" {
  description = "Custom AMI for node group"
  type        = bool
  default     = false
}

variable "enable_bottlerocket_ami" {
  description = "Bottlerocket AMI for node group"
  type        = bool
  default     = false
}

variable "max_unavailable_nodes" {
  description = "Desired max number of unavailable worker nodes during node group update."
  type        = number
  default     = 1
}

variable "max_unavailable_percentage_nodes" {
  description = "Desired max percentage of unavailable worker nodes during node group update."
  type        = number
  default     = null
}

variable "audit_ami" {
  description = "Node group to use Audit AMI"
  type        = bool
  default     = false
}

variable "eks_audit_ami_owner" {
  description = "Audit AMI Owner which is Audit account ID"
  type        = string
  default     = "602401143452"
}

variable "eks_bottlerocket_ami_owner" {
  description = "Bottlerocket AMI Owner"
  type        = string
  default     = "651937483462"
}

variable "enable_notifications" {
  description = "Adding SNS Topic to ASG"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "ASG SNS Topic arn"
  type        = string
  default     = ""
}

###############
### Fargate ###
###############

variable "fargate_profiles" {
  description = "Paramters which are required for creating fargate profile"
  default     = {}
  type = map(object({
    subnets   = list(string)
    tags      = map(string)
    labels    = map(string)
    namespace = string
  }))
}

variable "account_id" {
  description = "Provide the account ID"
  type        = string
  default     = ""
}

variable "create_fargate_role" {
  description = "Provide value to create role for fargate"
  type        = bool
  default     = false
}

#############
###  KMS  ###
#############

variable "deletion_window_in_days" {
  type        = number
  default     = 7
  description = "Duration in days after which the key is deleted after destruction of the resource"
}

variable "enable_key_rotation" {
  type        = bool
  default     = true
  description = "Specifies whether key rotation is enabled"
}

variable "description" {
  type        = string
  default     = "For EKS CLuster"
  description = "The description of the key as viewed in AWS console"
}

variable "policy" {
  type        = string
  default     = ""
  description = "A valid KMS policy JSON document. Note that if the policy document is not specific enough (but still valid), Terraform may view the policy as constantly changing in a terraform plan. In this case, please make sure you use the verbose/specific version of the policy."
}

variable "key_usage" {
  type        = string
  default     = "ENCRYPT_DECRYPT"
  description = "Specifies the intended use of the key. Valid values: `ENCRYPT_DECRYPT` or `SIGN_VERIFY`."
}

variable "customer_master_key_spec" {
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair and the encryption algorithms or signing algorithms that the key supports. Valid values: `SYMMETRIC_DEFAULT`, `RSA_2048`, `RSA_3072`, `RSA_4096`, `ECC_NIST_P256`, `ECC_NIST_P384`, `ECC_NIST_P521`, or `ECC_SECG_P256K1`."
}

variable "multi_region" {
  type        = bool
  default     = false
  description = "Indicates whether the KMS key is a multi-Region (true) or regional (false) key."
}

variable "alias" {
  type        = string
  description = "Provide the alias for the KMS"
  default     = "EKS"
}

variable "create_kms" {
  description = "If true it will create KMS for EKS"
  type        = bool
  default     = true
}

variable "kms_arn" {
  description = "Provide custom KMS ARN"
  type        = string
  default     = ""
}

###############
### SSH Key ###
###############
variable "create_key_pair" {
  description = "Controls if key pair should be created"
  type        = bool
  default     = true
}


variable "download_key_pair_locally" {
  description = "Controls if key pair should be downnloaded"
  type        = bool
  default     = false
}


variable "key_name" {
  description = "The name for the key pair."
  type        = string
  default     = null
}

###############
### Add ons ###
###############

variable "addon_create_vpc_cni" {
  type    = bool
  default = true
}

variable "addon_vpc_cni_version" {
  type    = string
  default = "v1.11.2-eksbuild.1"
}

variable "vpc_cni_version" {
  type    = string
  default = "default"
}

variable "addon_create_kube_proxy" {
  type    = bool
  default = true
}

variable "addon_kube_proxy_version" {
  type    = string
  default = "v1.22.6-eksbuild.1"
}

variable "kube_proxy_version" {
  type    = string
  default = "default"
}

variable "addon_create_coredns" {
  type    = bool
  default = true
}

variable "addon_coredns_version" {
  type    = string
  default = "v1.8.7-eksbuild.1"
}

variable "coredns_version" {
  type    = string
  default = "default"
}

##########################
### aws-auth ConfigMap ###
##########################
variable "map_roles" {
  description = "Granting access of cluster to roles"
  type        = any
}

variable "map_users" {
  description = "Granting access of cluster to iam users"
  type        = any
}

variable "custom_oidc_thumbprints" {
  description = "Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)"
  type        = list(string)
  default     = []
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`"
  type        = any
  default     = {}
}

variable "suspend_azrebalance" {
  description = "suspend AZrebalance"
  type        = bool
  default     = false
}

# variable "security_group_enabled" {
#   type        = bool
#   default     = true
#   description = "Specifies whether addition sg is enabled"
# }

variable "cluster_security_group_additional_rules" {
  description = "List of additional security group rules to add to the cluster security group created."
  type        = any
  default     = {}
}

variable "worker_security_group_additional_rules" {
  description = "List of additional security group rules to add to the worker security group created."
  type        = any
  default     = {}
}

variable "custom_policy" {
  description = "Policy document. This is a JSON formatted string."
  type        = string
  default     = null
}

variable "bootstrap_admin_role_arn" {
  description = "IAM role ARN used to bootstrap EKS access (must be IAM role ARN, NOT STS assumed-role ARN)."
  type        = string
}