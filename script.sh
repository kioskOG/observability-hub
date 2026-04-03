# #!/bin/bash

# set -euo pipefail
# export AWS_PAGER=""


# # Colors for output
# RED='\033[0;31m'      # Red
# GREEN='\033[0;32m'    # Green
# YELLOW='\033[0;33m'   # Yellow
# BLUE='\033[0;34m'     # Blue
# NC='\033[0m'          # No Color (reset)


# function prompt_input() {
#   local var_name="$1"
#   local prompt="$2"
#   local default="$3"

#   read -p "$(echo -e "${BLUE}${prompt} [${default}]: ${NC}")" input
#   input="${input:-$default}"
#   export $var_name="$input"
# }

# function bucket_exists() {
#   aws s3api head-bucket --bucket "$1" 2>/dev/null
# }

# function create_s3_bucket_if_not_exists() {
#   local bucket="$1"
#   local region="$2"
#   if bucket_exists "$bucket"; then
#     echo -e "${GREEN}✔️  Bucket '$bucket' already exists, skipping...${NC}"
#   else
#     aws s3 mb "s3://$bucket" --region "$region"
#     echo -e "${YELLOW}🪣 Created bucket: $bucket${NC}"
#   fi
# }

# function create_policy_if_not_exists() {
#   local name="$1"
#   local file="$2"

#   if aws iam list-policies --scope Local --query "Policies[?PolicyName=='${name}'] | [0]" --output text | grep -q "${name}"; then
#     echo -e "${GREEN}✔️  IAM Policy '$name' already exists, skipping...${NC}"
#   else
#     aws iam create-policy --policy-name "$name" --policy-document file://"$file"
#     echo -e "${YELLOW}📜 Created IAM Policy: $name${NC}"
#   fi
# }

# function create_role_if_not_exists() {
#   local name="$1"
#   local file="$2"

#   if aws iam get-role --role-name "$name" >/dev/null 2>&1; then
#     echo -e "${GREEN}✔️  Role '$name' already exists, skipping...${NC}"
#   else
#     aws iam create-role --role-name "$name" --assume-role-policy-document file://"$file"
#     echo -e "${YELLOW}🔐 Created IAM Role: $name${NC}"
#   fi
# }

# function attach_policy_if_not_attached() {
#   local role="$1"
#   local policy_name="$2"
#   local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

#   if aws iam list-attached-role-policies --role-name "$role" | grep -q "$policy_name"; then
#     echo -e "${GREEN}✔️  Policy $policy_name already attached to $role${NC}"
#   else
#     aws iam attach-role-policy --role-name "$role" --policy-arn "$policy_arn"
#     echo -e "${YELLOW}📌 Attached policy $policy_name to $role${NC}"
#   fi
# }

# # ---------------------------------------------------------------------------
# # AWS provisioning: S3 buckets + IAM policies/roles (mutating account state).
# # Set OBSERVABILITY_PROVISION_AWS=yes|no to skip this prompt (e.g. CI or Makefile).
# # If "no", only local JSON + Helm values are generated; you manage S3/IAM via
# # Terraform, CloudFormation, AWS Console, etc.
# # ---------------------------------------------------------------------------
# provision_aws=""

# resolve_provision_choice() {
#   local raw="${1:-}"
#   raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
#   case "$raw" in
#     y|yes|true|1) echo "yes" ;;
#     *) echo "no" ;;
#   esac
# }

# if [[ -n "${OBSERVABILITY_PROVISION_AWS:-}" ]]; then
#   provision_aws="$(resolve_provision_choice "$OBSERVABILITY_PROVISION_AWS")"
#   echo -e "${BLUE}Using OBSERVABILITY_PROVISION_AWS=${OBSERVABILITY_PROVISION_AWS} → provision AWS resources: ${provision_aws}${NC}"
# else
#   echo ""
#   echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
#   echo -e "${YELLOW}  AWS account changes (S3 buckets + IAM policies & roles)${NC}"
#   echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
#   echo -e "This script can either:"
#   echo -e "  ${GREEN}(y)${NC}  Create/update ${YELLOW}S3 buckets${NC} and ${YELLOW}IAM${NC} policies & roles via AWS CLI (mutating)."
#   echo -e "  ${GREEN}(N)${NC}  ${BLUE}Skip${NC} all of that — you manage S3/IAM yourself (Terraform, Console, etc.)."
#   echo -e "       The script will still write ${BLUE}policy/trust JSON files${NC} under loki/, mimir/, tempo/, pyroscope/"
#   echo -e "       and ${BLUE}generate Helm override YAML${NC} from templates (you must supply existing IRSA role ARNs)."
#   echo ""
#   read -r -p "$(echo -e "${BLUE}Provision S3 + IAM in this AWS account? [y/N]: ${NC}")" _provision_answer
#   provision_aws="$(resolve_provision_choice "$_provision_answer")"
# fi

# if [[ "$provision_aws" == "no" ]]; then
#   echo -e "${GREEN}✔️  AWS provisioning disabled — no S3 mb / iam create-* / attach-role-policy will be run.${NC}"
# else
#   echo -e "${YELLOW}⚠️  AWS provisioning ENABLED — this script will create or verify S3 buckets and IAM resources.${NC}"
# fi
# echo ""

# ### -------------------------------------------------------------
# # Start Script
# echo -e "${BLUE}🧠 Providing Cluster & Region Info${NC}"
# prompt_input cluster_name "Enter your EKS cluster name" "my-cluster"
# export cluster_name="$cluster_name"
# export cluster_name_lower=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')


# prompt_input region_name "Enter AWS region where the EKS cluster runs (EKS API, OIDC issuer, IAM trust)" "ap-southeast-1"
# prompt_input s3_bucket_region "Enter AWS region where observability S3 buckets live (can differ from cluster; SDK + endpoints use this)" "${region_name}"

# ### Export variables used later
# export cluster_name region_name s3_bucket_region

# echo -e "${BLUE}🪣 Gathering S3 bucket input for monitoring components${NC}"

# prompt_input loki_chunk_bucket "Enter S3 bucket name for Loki chunks" "loki-chunks"
# export env_loki_chunk_bucket="${cluster_name_lower}-${loki_chunk_bucket}"
# prompt_input loki_ruler_bucket "Enter S3 bucket name for Loki ruler" "loki-ruler"
# export env_loki_ruler_bucket="${cluster_name_lower}-${loki_ruler_bucket}"

# prompt_input mimir_chunk_bucket "Enter S3 bucket name for Mimir chunks" "mimir-chunks"
# export env_mimir_chunk_bucket="${cluster_name_lower}-${mimir_chunk_bucket}"
# prompt_input mimir_ruler_bucket "Enter S3 bucket name for Mimir ruler" "mimir-ruler"
# export env_mimir_ruler_bucket="${cluster_name_lower}-${mimir_ruler_bucket}"

# prompt_input tempo_chunk_bucket "Enter S3 bucket name for Tempo chunks" "tempo-chunks"
# export env_tempo_chunk_bucket="${cluster_name_lower}-${tempo_chunk_bucket}"

# prompt_input pyroscope_chunk_bucket "Enter S3 bucket name for Pyroscope chunks" "pyroscope-chunks"
# export env_pyroscope_chunk_bucket="${cluster_name_lower}-${pyroscope_chunk_bucket}"

# ### Create Buckets (only when user opted in)
# if [[ "$provision_aws" == "yes" ]]; then
#   echo -e "${BLUE}🚀 Creating or verifying S3 buckets...${NC}"
#   create_s3_bucket_if_not_exists "$env_loki_chunk_bucket" "$s3_bucket_region"
#   create_s3_bucket_if_not_exists "$env_loki_ruler_bucket" "$s3_bucket_region"
#   create_s3_bucket_if_not_exists "$env_mimir_chunk_bucket" "$s3_bucket_region"
#   create_s3_bucket_if_not_exists "$env_mimir_ruler_bucket" "$s3_bucket_region"
#   create_s3_bucket_if_not_exists "$env_tempo_chunk_bucket" "$s3_bucket_region"
#   create_s3_bucket_if_not_exists "$env_pyroscope_chunk_bucket" "$s3_bucket_region"
# else
#   echo -e "${BLUE}⏭️  Skipping S3 bucket creation (manage buckets yourself).${NC}"
#   echo -e "    Expected bucket names for generated policies/Helm: ${YELLOW}${env_loki_chunk_bucket}${NC}, ${YELLOW}${env_loki_ruler_bucket}${NC}, ..."
# fi

# ### -------------------------------------------------------------
# # IAM Setup (read-only first: account + OIDC for trust policy JSON)
# echo -e "${BLUE}🔍 Fetching AWS Account ID & EKS OIDC Provider Info${NC}"
# account_id=$(aws sts get-caller-identity --query "Account" --output text)
# idp_id=$(aws eks describe-cluster --name "${cluster_name}" --region "${region_name}" \
#   --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $NF}')

# ### -------------------------------------------------------------
# # Loki Policy + Role
# cat > ./loki/loki-s3-policy.json <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "LokiStorage",
#       "Effect": "Allow",
#       "Action": ["s3:ListBucket", "s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
#       "Resource": [
#         "arn:aws:s3:::${env_loki_chunk_bucket}",
#         "arn:aws:s3:::${env_loki_chunk_bucket}/*",
#         "arn:aws:s3:::${env_loki_ruler_bucket}",
#         "arn:aws:s3:::${env_loki_ruler_bucket}/*"
#       ]
#     }
#   ]
# }
# EOF

# # IRSA: aud must be sts.amazonaws.com. sub uses StringLike so any ServiceAccount in namespace loki matches
# # (Helm release name can change the SA name from "loki" to e.g. "myrelease"; compactor uses the chart-wide SA).
# cat > ./loki/loki-trust-policy.json <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity",
#       "Condition": {
#         "StringEquals": {
#           "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
#         },
#         "StringLike": {
#           "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:loki:*"
#         }
#       }
#     }
#   ]
# }
# EOF

# if [[ "$provision_aws" == "yes" ]]; then
#   create_policy_if_not_exists "LokiS3AccessPolicy" "./loki/loki-s3-policy.json"
#   create_role_if_not_exists "LokiServiceAccountRole" "./loki/loki-trust-policy.json"
#   attach_policy_if_not_attached "LokiServiceAccountRole" "LokiS3AccessPolicy"
#   export loki_role_arn=$(aws iam get-role --role-name LokiServiceAccountRole --query "Role.Arn" --output text)
# else
#   echo -e "${BLUE}⏭️  Skipping Loki IAM create/attach (manage policies & LokiServiceAccountRole yourself).${NC}"
# fi

# ### -------------------------------------------------------------
# # Repeat for Mimir, Tempo, Pyroscope (example below for Mimir only – repeat pattern for others)

# cat > ./mimir/mimir-s3-policy.json <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "MimirStorage",
#       "Effect": "Allow",
#       "Action": ["s3:ListBucket", "s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
#       "Resource": [
#         "arn:aws:s3:::${env_mimir_chunk_bucket}",
#         "arn:aws:s3:::${env_mimir_chunk_bucket}/*",
#         "arn:aws:s3:::${env_mimir_ruler_bucket}",
#         "arn:aws:s3:::${env_mimir_ruler_bucket}/*"
#       ]
#     }
#   ]
# }
# EOF

# cat > ./mimir/mimir-trust-policy.json <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity",
#       "Condition": {
#         "StringEquals": {
#           "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
#         },
#         "StringLike": {
#           "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:mimir:*"
#         }
#       }
#     }
#   ]
# }
# EOF

# if [[ "$provision_aws" == "yes" ]]; then
#   create_policy_if_not_exists "MimirS3AccessPolicy" "./mimir/mimir-s3-policy.json"
#   create_role_if_not_exists "MimirServiceAccountRole" "./mimir/mimir-trust-policy.json"
#   attach_policy_if_not_attached "MimirServiceAccountRole" "MimirS3AccessPolicy"
#   export mimir_role_arn=$(aws iam get-role --role-name MimirServiceAccountRole --query "Role.Arn" --output text)
# else
#   echo -e "${BLUE}⏭️  Skipping Mimir IAM create/attach (manage MimirServiceAccountRole yourself).${NC}"
# fi

# cat > ./tempo/tempo-s3-policy.json <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "TempoStorage",
#             "Effect": "Allow",
#             "Action": [
#                 "s3:ListBucket",
#                 "s3:PutObject",
#                 "s3:GetObject",
#                 "s3:DeleteObject"
#             ],
#             "Resource": [
#                 "arn:aws:s3:::${env_tempo_chunk_bucket}",
#                 "arn:aws:s3:::${env_tempo_chunk_bucket}/*"
#         ]
#     }
#     ]
# }
# EOF

# cat > ./tempo/tempo-trust-policy.json <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Principal": {
#                 "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
#             },
#             "Action": "sts:AssumeRoleWithWebIdentity",
#             "Condition": {
#                 "StringEquals": {
#                     "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
#                 },
#                 "StringLike": {
#                     "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:tempo:*"
#                 }
#             }
#         }
#     ]
# }
# EOF

# if [[ "$provision_aws" == "yes" ]]; then
#   create_policy_if_not_exists "TempoS3AccessPolicy" "./tempo/tempo-s3-policy.json"
#   create_role_if_not_exists "TempoServiceAccountRole" "./tempo/tempo-trust-policy.json"
#   attach_policy_if_not_attached "TempoServiceAccountRole" "TempoS3AccessPolicy"
#   export tempo_role_arn=$(aws iam get-role --role-name TempoServiceAccountRole --query "Role.Arn" --output text)
# else
#   echo -e "${BLUE}⏭️  Skipping Tempo IAM create/attach (manage TempoServiceAccountRole yourself).${NC}"
# fi


# cat > ./pyroscope/pyroscope-s3-policy.json <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "PyroscopeStorage",
#             "Effect": "Allow",
#             "Action": [
#                 "s3:ListBucket",
#                 "s3:PutObject",
#                 "s3:GetObject",
#                 "s3:DeleteObject"
#             ],
#             "Resource": [
#                 "arn:aws:s3:::${env_pyroscope_chunk_bucket}",
#                 "arn:aws:s3:::${env_pyroscope_chunk_bucket}/*"
#         ]
#     }
#     ]
# }
# EOF

# cat > ./pyroscope/pyroscope-trust-policy.json <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Principal": {
#                 "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
#             },
#             "Action": "sts:AssumeRoleWithWebIdentity",
#             "Condition": {
#                 "StringEquals": {
#                     "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
#                 },
#                 "StringLike": {
#                     "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:pyroscope:*"
#                 }
#             }
#         }
#     ]
# }
# EOF


# if [[ "$provision_aws" == "yes" ]]; then
#   create_policy_if_not_exists "PyroscopeS3AccessPolicy" "./pyroscope/pyroscope-s3-policy.json"
#   create_role_if_not_exists "PyroscopeServiceAccountRole" "./pyroscope/pyroscope-trust-policy.json"
#   attach_policy_if_not_attached "PyroscopeServiceAccountRole" "PyroscopeS3AccessPolicy"
#   export pyroscope_role_arn=$(aws iam get-role --role-name PyroscopeServiceAccountRole --query "Role.Arn" --output text)
# else
#   echo -e "${BLUE}⏭️  Skipping Pyroscope IAM create/attach (manage PyroscopeServiceAccountRole yourself).${NC}"
# fi

# ### -------------------------------------------------------------
# # IRSA role ARNs for Helm (required when AWS provisioning was skipped)
# if [[ "$provision_aws" == "no" ]]; then
#   echo ""
#   echo -e "${YELLOW}Enter existing IAM role ARNs for Kubernetes service accounts (IRSA):${NC}"
#   prompt_input loki_role_arn      "Loki SA role ARN      (loki:loki)"             ""
#   prompt_input mimir_role_arn     "Mimir SA role ARN     (mimir:mimir)"           ""
#   prompt_input tempo_role_arn     "Tempo SA role ARN     (tempo:tempo)"           ""
#   prompt_input pyroscope_role_arn "Pyroscope SA role ARN (pyroscope:pyroscope)"     ""

#   if [[ -z "$loki_role_arn" || -z "$mimir_role_arn" || -z "$tempo_role_arn" || -z "$pyroscope_role_arn" ]]; then
#     echo -e "${RED}Error: One or more IRSA role ARNs are empty. Paste full ARNs (e.g. arn:aws:iam::123456789012:role/MyLokiRole) or re-run and enable AWS provisioning.${NC}"
#     exit 1
#   fi
# fi

# ### -------------------------------------------------------------
# # Generate final override values from template
# echo -e "${BLUE}📦 Generating Helm override values...${NC}"
# envsubst < ./loki/loki-values-template.yaml > ./loki/loki-override-values.yaml
# envsubst < ./mimir/mimir-values-template.yaml > ./mimir/mimir-override-values.yaml
# envsubst < ./tempo/tempo-values-template.yaml > ./tempo/tempo-override-values.yaml
# envsubst < ./pyroscope/pyroscope-values-template.yaml > ./pyroscope/pyroscope-override-values.yaml

# echo -e "${GREEN}📄 Generated override YAMLs:${NC}"
# ls -1 ./loki/*override-values.yaml ./mimir/*override-values.yaml ./tempo/*override-values.yaml ./pyroscope/*override-values.yaml

# ### -------------------------------------------------------------
# # State file for cleanup-aws.sh --from-state (POC teardown)
# OBSERVABILITY_STATE_FILE="${OBSERVABILITY_STATE_FILE:-./.observability-poc-aws.state}"
# write_poc_state_file() {
#   umask 077
#   cat > "$OBSERVABILITY_STATE_FILE" <<EOF
# # observability-hub — generated by script.sh; use: ./cleanup-aws.sh --from-state
# OBSERVABILITY_STATE_VERSION=1
# provision_aws=${provision_aws}
# cluster_name=${cluster_name}
# region_name=${region_name}
# s3_bucket_region=${s3_bucket_region}
# cluster_name_lower=${cluster_name_lower}
# env_loki_chunk_bucket=${env_loki_chunk_bucket}
# env_loki_ruler_bucket=${env_loki_ruler_bucket}
# env_mimir_chunk_bucket=${env_mimir_chunk_bucket}
# env_mimir_ruler_bucket=${env_mimir_ruler_bucket}
# env_tempo_chunk_bucket=${env_tempo_chunk_bucket}
# env_pyroscope_chunk_bucket=${env_pyroscope_chunk_bucket}
# loki_role_arn=${loki_role_arn:-}
# mimir_role_arn=${mimir_role_arn:-}
# tempo_role_arn=${tempo_role_arn:-}
# pyroscope_role_arn=${pyroscope_role_arn:-}
# EOF
#   echo -e "${BLUE}📝 Wrote ${OBSERVABILITY_STATE_FILE} (for ${YELLOW}./cleanup-aws.sh --from-state${NC}${BLUE})${NC}"
# }
# write_poc_state_file

# ### -------------------------------------------------------------
# # Final Summary
# echo ""
# echo -e "${GREEN}✅ IRSA role ARNs for Helm values:${NC}"
# echo "  Loki     : $loki_role_arn"
# echo "  Mimir    : $mimir_role_arn"
# echo "  Tempo    : $tempo_role_arn"
# echo "  Pyroscope: $pyroscope_role_arn"

# if [[ "$provision_aws" == "yes" ]]; then
#   echo -e "${GREEN}\n🎉 S3 + IAM provisioning finished (or resources were already present).${NC}"
# else
#   echo -e "${GREEN}\n🎉 Local policy JSON + Helm overrides generated (no S3/IAM mutations were performed).${NC}"
# fi
# echo -e "🚀 Install charts with: ${BLUE}make install${NC} (after ${BLUE}make init${NC} secrets) or per-component ${BLUE}make install-loki${NC} etc.${NC}"
# echo -e "${YELLOW}Tip:${NC} To skip the prompt next time: ${BLUE}export OBSERVABILITY_PROVISION_AWS=no${NC} or ${BLUE}yes${NC}"
# echo -e "${YELLOW}POC cleanup:${NC} ${BLUE}./cleanup-aws.sh --dry-run --from-state${NC} then ${BLUE}./cleanup-aws.sh --from-state${NC} (or ${BLUE}make aws-cleanup-dry-run${NC} / ${BLUE}make aws-cleanup${NC})"




#!/bin/bash

set -euo pipefail
export AWS_PAGER=""


# Colors for output
RED='\033[0;31m'      # Red
GREEN='\033[0;32m'    # Green
YELLOW='\033[0;33m'   # Yellow
BLUE='\033[0;34m'     # Blue
NC='\033[0m'          # No Color (reset)


function prompt_input() {
  local var_name="$1"
  local prompt="$2"
  local default="$3"

  read -p "$(echo -e "${BLUE}${prompt} [${default}]: ${NC}")" input
  input="${input:-$default}"
  export $var_name="$input"
}

function bucket_exists() {
  aws s3api head-bucket --bucket "$1" 2>/dev/null
}

function create_s3_bucket_if_not_exists() {
  local bucket="$1"
  local region="$2"
  if bucket_exists "$bucket"; then
    echo -e "${GREEN}✔️  Bucket '$bucket' already exists, skipping...${NC}"
  else
    aws s3 mb "s3://$bucket" --region "$region"
    echo -e "${YELLOW}🪣 Created bucket: $bucket${NC}"
  fi
}

function create_policy_if_not_exists() {
  local name="$1"
  local file="$2"

  if aws iam list-policies --scope Local --query "Policies[?PolicyName=='${name}'] | [0]" --output text | grep -q "${name}"; then
    echo -e "${GREEN}✔️  IAM Policy '$name' already exists, skipping...${NC}"
  else
    aws iam create-policy --policy-name "$name" --policy-document file://"$file"
    echo -e "${YELLOW}📜 Created IAM Policy: $name${NC}"
  fi
}

function create_role_if_not_exists() {
  local name="$1"
  local file="$2"

  if aws iam get-role --role-name "$name" >/dev/null 2>&1; then
    echo -e "${GREEN}✔️  Role '$name' already exists, skipping...${NC}"
  else
    aws iam create-role --role-name "$name" --assume-role-policy-document file://"$file"
    echo -e "${YELLOW}🔐 Created IAM Role: $name${NC}"
  fi
}

function attach_policy_if_not_attached() {
  local role="$1"
  local policy_name="$2"
  local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

  if aws iam list-attached-role-policies --role-name "$role" | grep -q "$policy_name"; then
    echo -e "${GREEN}✔️  Policy $policy_name already attached to $role${NC}"
  else
    aws iam attach-role-policy --role-name "$role" --policy-arn "$policy_arn"
    echo -e "${YELLOW}📌 Attached policy $policy_name to $role${NC}"
  fi
}

# ---------------------------------------------------------------------------
# AWS provisioning: S3 buckets + IAM policies/roles (mutating account state).
# Set OBSERVABILITY_PROVISION_AWS=yes|no to skip this prompt (e.g. CI or Makefile).
# If "no", only local JSON + Helm values are generated; you manage S3/IAM via
# Terraform, CloudFormation, AWS Console, etc.
# ---------------------------------------------------------------------------
provision_aws=""

resolve_provision_choice() {
  local raw="${1:-}"
  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    y|yes|true|1) echo "yes" ;;
    *) echo "no" ;;
  esac
}

if [[ -n "${OBSERVABILITY_PROVISION_AWS:-}" ]]; then
  provision_aws="$(resolve_provision_choice "$OBSERVABILITY_PROVISION_AWS")"
  echo -e "${BLUE}Using OBSERVABILITY_PROVISION_AWS=${OBSERVABILITY_PROVISION_AWS} → provision AWS resources: ${provision_aws}${NC}"
else
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  AWS account changes (S3 buckets + IAM policies & roles)${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "This script can either:"
  echo -e "  ${GREEN}(y)${NC}  Create/update ${YELLOW}S3 buckets${NC} and ${YELLOW}IAM${NC} policies & roles via AWS CLI (mutating)."
  echo -e "  ${GREEN}(N)${NC}  ${BLUE}Skip${NC} all of that — you manage S3/IAM yourself (Terraform, Console, etc.)."
  echo -e "       The script will still write ${BLUE}policy/trust JSON files${NC} under loki/, mimir/, tempo/, pyroscope/"
  echo -e "       and ${BLUE}generate Helm override YAML${NC} from templates (you must supply existing IRSA role ARNs)."
  echo ""
  read -r -p "$(echo -e "${BLUE}Provision S3 + IAM in this AWS account? [y/N]: ${NC}")" _provision_answer
  provision_aws="$(resolve_provision_choice "$_provision_answer")"
fi

if [[ "$provision_aws" == "no" ]]; then
  echo -e "${GREEN}✔️  AWS provisioning disabled — no S3 mb / iam create-* / attach-role-policy will be run.${NC}"
else
  echo -e "${YELLOW}⚠️  AWS provisioning ENABLED — this script will create or verify S3 buckets and IAM resources.${NC}"
fi
echo ""

### -------------------------------------------------------------
# Start Script
echo -e "${BLUE}🧠 Providing Cluster & Region Info${NC}"
prompt_input cluster_name "Enter your EKS cluster name" "my-cluster"
export cluster_name="$cluster_name"
export cluster_name_lower=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')


prompt_input region_name "Enter AWS region where the EKS cluster runs (EKS API, OIDC issuer, IAM trust)" "ap-southeast-1"
prompt_input s3_bucket_region "Enter AWS region where observability S3 buckets live (can differ from cluster; SDK + endpoints use this)" "${region_name}"

### Export variables used later
export cluster_name region_name s3_bucket_region

echo -e "${BLUE}🪣 Gathering S3 bucket input for monitoring components${NC}"

prompt_input loki_chunk_bucket "Enter S3 bucket name for Loki chunks" "loki-chunks"
export env_loki_chunk_bucket="${cluster_name_lower}-${loki_chunk_bucket}"
prompt_input loki_ruler_bucket "Enter S3 bucket name for Loki ruler" "loki-ruler"
export env_loki_ruler_bucket="${cluster_name_lower}-${loki_ruler_bucket}"

prompt_input mimir_chunk_bucket "Enter S3 bucket name for Mimir chunks" "mimir-chunks"
export env_mimir_chunk_bucket="${cluster_name_lower}-${mimir_chunk_bucket}"
prompt_input mimir_ruler_bucket "Enter S3 bucket name for Mimir ruler" "mimir-ruler"
export env_mimir_ruler_bucket="${cluster_name_lower}-${mimir_ruler_bucket}"

prompt_input tempo_chunk_bucket "Enter S3 bucket name for Tempo chunks" "tempo-chunks"
export env_tempo_chunk_bucket="${cluster_name_lower}-${tempo_chunk_bucket}"

prompt_input pyroscope_chunk_bucket "Enter S3 bucket name for Pyroscope chunks" "pyroscope-chunks"
export env_pyroscope_chunk_bucket="${cluster_name_lower}-${pyroscope_chunk_bucket}"

### Create Buckets (only when user opted in)
if [[ "$provision_aws" == "yes" ]]; then
  echo -e "${BLUE}🚀 Creating or verifying S3 buckets...${NC}"
  create_s3_bucket_if_not_exists "$env_loki_chunk_bucket" "$s3_bucket_region"
  create_s3_bucket_if_not_exists "$env_loki_ruler_bucket" "$s3_bucket_region"
  create_s3_bucket_if_not_exists "$env_mimir_chunk_bucket" "$s3_bucket_region"
  create_s3_bucket_if_not_exists "$env_mimir_ruler_bucket" "$s3_bucket_region"
  create_s3_bucket_if_not_exists "$env_tempo_chunk_bucket" "$s3_bucket_region"
  create_s3_bucket_if_not_exists "$env_pyroscope_chunk_bucket" "$s3_bucket_region"
else
  echo -e "${BLUE}⏭️  Skipping S3 bucket creation (manage buckets yourself).${NC}"
  echo -e "    Expected bucket names for generated policies/Helm: ${YELLOW}${env_loki_chunk_bucket}${NC}, ${YELLOW}${env_loki_ruler_bucket}${NC}, ..."
fi

### -------------------------------------------------------------
# IAM Setup (read-only first: account + OIDC for trust policy JSON)
echo -e "${BLUE}🔍 Fetching AWS Account ID & EKS OIDC Provider Info${NC}"
account_id=$(aws sts get-caller-identity --query "Account" --output text)
idp_id=$(aws eks describe-cluster --name "${cluster_name}" --region "${region_name}" \
  --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $NF}')

### -------------------------------------------------------------
# Loki Policy + Role
cat > ./loki/loki-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LokiStorage",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::${env_loki_chunk_bucket}",
        "arn:aws:s3:::${env_loki_chunk_bucket}/*",
        "arn:aws:s3:::${env_loki_ruler_bucket}",
        "arn:aws:s3:::${env_loki_ruler_bucket}/*"
      ]
    }
  ]
}
EOF

# IRSA: aud must be sts.amazonaws.com. sub uses StringLike so any ServiceAccount in namespace loki matches
# (Helm release name can change the SA name from "loki" to e.g. "myrelease"; compactor uses the chart-wide SA).
cat > ./loki/loki-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:loki:*"
        }
      }
    }
  ]
}
EOF

if [[ "$provision_aws" == "yes" ]]; then
  create_policy_if_not_exists "LokiS3AccessPolicy" "./loki/loki-s3-policy.json"
  create_role_if_not_exists "LokiServiceAccountRole" "./loki/loki-trust-policy.json"
  attach_policy_if_not_attached "LokiServiceAccountRole" "LokiS3AccessPolicy"
  export loki_role_arn=$(aws iam get-role --role-name LokiServiceAccountRole --query "Role.Arn" --output text)
else
  echo -e "${BLUE}⏭️  Skipping Loki IAM create/attach (manage policies & LokiServiceAccountRole yourself).${NC}"
fi

### -------------------------------------------------------------
# Repeat for Mimir, Tempo, Pyroscope (example below for Mimir only – repeat pattern for others)

cat > ./mimir/mimir-s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "MimirStorage",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::${env_mimir_chunk_bucket}",
        "arn:aws:s3:::${env_mimir_chunk_bucket}/*",
        "arn:aws:s3:::${env_mimir_ruler_bucket}",
        "arn:aws:s3:::${env_mimir_ruler_bucket}/*"
      ]
    }
  ]
}
EOF

cat > ./mimir/mimir-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:mimir:*"
        }
      }
    }
  ]
}
EOF

if [[ "$provision_aws" == "yes" ]]; then
  create_policy_if_not_exists "MimirS3AccessPolicy" "./mimir/mimir-s3-policy.json"
  create_role_if_not_exists "MimirServiceAccountRole" "./mimir/mimir-trust-policy.json"
  attach_policy_if_not_attached "MimirServiceAccountRole" "MimirS3AccessPolicy"
  export mimir_role_arn=$(aws iam get-role --role-name MimirServiceAccountRole --query "Role.Arn" --output text)
else
  echo -e "${BLUE}⏭️  Skipping Mimir IAM create/attach (manage MimirServiceAccountRole yourself).${NC}"
fi

cat > ./tempo/tempo-s3-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "TempoStorage",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${env_tempo_chunk_bucket}",
                "arn:aws:s3:::${env_tempo_chunk_bucket}/*"
        ]
    }
    ]
}
EOF

cat > ./tempo/tempo-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:tempo:*"
                }
            }
        }
    ]
}
EOF

if [[ "$provision_aws" == "yes" ]]; then
  create_policy_if_not_exists "TempoS3AccessPolicy" "./tempo/tempo-s3-policy.json"
  create_role_if_not_exists "TempoServiceAccountRole" "./tempo/tempo-trust-policy.json"
  attach_policy_if_not_attached "TempoServiceAccountRole" "TempoS3AccessPolicy"
  export tempo_role_arn=$(aws iam get-role --role-name TempoServiceAccountRole --query "Role.Arn" --output text)
else
  echo -e "${BLUE}⏭️  Skipping Tempo IAM create/attach (manage TempoServiceAccountRole yourself).${NC}"
fi


cat > ./pyroscope/pyroscope-s3-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PyroscopeStorage",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${env_pyroscope_chunk_bucket}",
                "arn:aws:s3:::${env_pyroscope_chunk_bucket}/*"
        ]
    }
    ]
}
EOF

cat > ./pyroscope/pyroscope-trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_name}.amazonaws.com/id/${idp_id}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:pyroscope:*"
                }
            }
        }
    ]
}
EOF


if [[ "$provision_aws" == "yes" ]]; then
  create_policy_if_not_exists "PyroscopeS3AccessPolicy" "./pyroscope/pyroscope-s3-policy.json"
  create_role_if_not_exists "PyroscopeServiceAccountRole" "./pyroscope/pyroscope-trust-policy.json"
  attach_policy_if_not_attached "PyroscopeServiceAccountRole" "PyroscopeS3AccessPolicy"
  export pyroscope_role_arn=$(aws iam get-role --role-name PyroscopeServiceAccountRole --query "Role.Arn" --output text)
else
  echo -e "${BLUE}⏭️  Skipping Pyroscope IAM create/attach (manage PyroscopeServiceAccountRole yourself).${NC}"
fi

### -------------------------------------------------------------
# IRSA role ARNs for Helm (required when AWS provisioning was skipped)
if [[ "$provision_aws" == "no" ]]; then
  echo ""
  echo -e "${YELLOW}Enter existing IAM role ARNs for Kubernetes service accounts (IRSA):${NC}"
  prompt_input loki_role_arn      "Loki SA role ARN      (loki:loki)"             ""
  prompt_input mimir_role_arn     "Mimir SA role ARN     (mimir:mimir)"           ""
  prompt_input tempo_role_arn     "Tempo SA role ARN     (tempo:tempo)"           ""
  prompt_input pyroscope_role_arn "Pyroscope SA role ARN (pyroscope:pyroscope)"     ""

  if [[ -z "$loki_role_arn" || -z "$mimir_role_arn" || -z "$tempo_role_arn" || -z "$pyroscope_role_arn" ]]; then
    echo -e "${RED}Error: One or more IRSA role ARNs are empty. Paste full ARNs (e.g. arn:aws:iam::123456789012:role/MyLokiRole) or re-run and enable AWS provisioning.${NC}"
    exit 1
  fi
fi

### -------------------------------------------------------------
# Generate final override values from template
# Restrict which ${VAR} names envsubst expands. A bare envsubst would wipe nginx
# variables like $remote_addr / $http_x_scope_orgid embedded in gateway configs.
echo -e "${BLUE}📦 Generating Helm override values...${NC}"
OBSERVABILITY_ENVSUBST_FORMAT='${s3_bucket_region} ${env_loki_chunk_bucket} ${env_loki_ruler_bucket} ${loki_role_arn} ${env_mimir_ruler_bucket} ${env_mimir_chunk_bucket} ${mimir_role_arn} ${env_tempo_chunk_bucket} ${tempo_role_arn} ${env_pyroscope_chunk_bucket} ${pyroscope_role_arn}'
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < ./loki/loki-values-template.yaml > ./loki/loki-override-values.yaml
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < ./mimir/mimir-values-template.yaml > ./mimir/mimir-override-values.yaml
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < ./tempo/tempo-values-template.yaml > ./tempo/tempo-override-values.yaml
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < ./pyroscope/pyroscope-values-template.yaml > ./pyroscope/pyroscope-override-values.yaml

echo -e "${GREEN}📄 Generated override YAMLs:${NC}"
ls -1 ./loki/*override-values.yaml ./mimir/*override-values.yaml ./tempo/*override-values.yaml ./pyroscope/*override-values.yaml

### -------------------------------------------------------------
# State file for cleanup-aws.sh --from-state (POC teardown)
OBSERVABILITY_STATE_FILE="${OBSERVABILITY_STATE_FILE:-./.observability-poc-aws.state}"
write_poc_state_file() {
  umask 077
  cat > "$OBSERVABILITY_STATE_FILE" <<EOF
# observability-hub — generated by script.sh; use: ./cleanup-aws.sh --from-state
OBSERVABILITY_STATE_VERSION=1
provision_aws=${provision_aws}
cluster_name=${cluster_name}
region_name=${region_name}
s3_bucket_region=${s3_bucket_region}
cluster_name_lower=${cluster_name_lower}
env_loki_chunk_bucket=${env_loki_chunk_bucket}
env_loki_ruler_bucket=${env_loki_ruler_bucket}
env_mimir_chunk_bucket=${env_mimir_chunk_bucket}
env_mimir_ruler_bucket=${env_mimir_ruler_bucket}
env_tempo_chunk_bucket=${env_tempo_chunk_bucket}
env_pyroscope_chunk_bucket=${env_pyroscope_chunk_bucket}
loki_role_arn=${loki_role_arn:-}
mimir_role_arn=${mimir_role_arn:-}
tempo_role_arn=${tempo_role_arn:-}
pyroscope_role_arn=${pyroscope_role_arn:-}
EOF
  echo -e "${BLUE}📝 Wrote ${OBSERVABILITY_STATE_FILE} (for ${YELLOW}./cleanup-aws.sh --from-state${NC}${BLUE})${NC}"
}
write_poc_state_file

### -------------------------------------------------------------
# Final Summary
echo ""
echo -e "${GREEN}✅ IRSA role ARNs for Helm values:${NC}"
echo "  Loki     : $loki_role_arn"
echo "  Mimir    : $mimir_role_arn"
echo "  Tempo    : $tempo_role_arn"
echo "  Pyroscope: $pyroscope_role_arn"

if [[ "$provision_aws" == "yes" ]]; then
  echo -e "${GREEN}\n🎉 S3 + IAM provisioning finished (or resources were already present).${NC}"
else
  echo -e "${GREEN}\n🎉 Local policy JSON + Helm overrides generated (no S3/IAM mutations were performed).${NC}"
fi
echo -e "🚀 Install charts with: ${BLUE}make install${NC} (after ${BLUE}make init${NC} secrets) or per-component ${BLUE}make install-loki${NC} etc.${NC}"
echo -e "${YELLOW}Tip:${NC} To skip the prompt next time: ${BLUE}export OBSERVABILITY_PROVISION_AWS=no${NC} or ${BLUE}yes${NC}"
echo -e "${YELLOW}POC cleanup:${NC} ${BLUE}./cleanup-aws.sh --dry-run --from-state${NC} then ${BLUE}./cleanup-aws.sh --from-state${NC} (or ${BLUE}make aws-cleanup-dry-run${NC} / ${BLUE}make aws-cleanup${NC})"