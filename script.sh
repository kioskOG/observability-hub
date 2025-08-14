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

### -------------------------------------------------------------
# Start Script
echo -e "${BLUE}🧠 Providing Cluster & Region Info${NC}"
prompt_input cluster_name "Enter your EKS cluster name" "my-cluster"
export cluster_name="$cluster_name"
export cluster_name_lower=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')


prompt_input region_name "Enter AWS region (same as cluster region)" "ap-southeast-1"

### Export variables used later
export cluster_name region_name

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

### Create Buckets
echo -e "${BLUE}🚀 Creating or verifying S3 buckets...${NC}"

create_s3_bucket_if_not_exists "$env_loki_chunk_bucket" "$region_name"
create_s3_bucket_if_not_exists "$env_loki_ruler_bucket" "$region_name"
create_s3_bucket_if_not_exists "$env_mimir_chunk_bucket" "$region_name"
create_s3_bucket_if_not_exists "$env_mimir_ruler_bucket" "$region_name"
create_s3_bucket_if_not_exists "$env_tempo_chunk_bucket" "$region_name"
create_s3_bucket_if_not_exists "$env_pyroscope_chunk_bucket" "$region_name"

### -------------------------------------------------------------
# IAM Setup
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
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com",
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:loki:loki"
        }
      }
    }
  ]
}
EOF

create_policy_if_not_exists "LokiS3AccessPolicy" "./loki/loki-s3-policy.json"
create_role_if_not_exists "LokiServiceAccountRole" "./loki/loki-trust-policy.json"
attach_policy_if_not_attached "LokiServiceAccountRole" "LokiS3AccessPolicy"
export loki_role_arn=$(aws iam get-role --role-name LokiServiceAccountRole --query "Role.Arn" --output text)

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
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com",
          "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:mimir:mimir"
        }
      }
    }
  ]
}
EOF

create_policy_if_not_exists "MimirS3AccessPolicy" "./mimir/mimir-s3-policy.json"
create_role_if_not_exists "MimirServiceAccountRole" "./mimir/mimir-trust-policy.json"
attach_policy_if_not_attached "MimirServiceAccountRole" "MimirS3AccessPolicy"
export mimir_role_arn=$(aws iam get-role --role-name MimirServiceAccountRole --query "Role.Arn" --output text)

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
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com",
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:tempo:tempo"
                }
            }
        }
    ]
}
EOF

create_policy_if_not_exists "TempoS3AccessPolicy" "./tempo/tempo-s3-policy.json"
create_role_if_not_exists "TempoServiceAccountRole" "./tempo/tempo-trust-policy.json"
attach_policy_if_not_attached "TempoServiceAccountRole" "TempoS3AccessPolicy"
export tempo_role_arn=$(aws iam get-role --role-name TempoServiceAccountRole --query "Role.Arn" --output text)


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
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:aud": "sts.amazonaws.com",
                    "oidc.eks.${region_name}.amazonaws.com/id/${idp_id}:sub": "system:serviceaccount:pyroscope:pyroscope"
                }
            }
        }
    ]
}
EOF


create_policy_if_not_exists "PyroscopeS3AccessPolicy" "./pyroscope/pyroscope-s3-policy.json"
create_role_if_not_exists "PyroscopeServiceAccountRole" "./pyroscope/pyroscope-trust-policy.json"
attach_policy_if_not_attached "PyroscopeServiceAccountRole" "PyroscopeS3AccessPolicy"
export pyroscope_role_arn=$(aws iam get-role --role-name PyroscopeServiceAccountRole --query "Role.Arn" --output text)


### -------------------------------------------------------------
# Repeat same logic for tempo, pyroscope if needed...

### -------------------------------------------------------------
# Generate final override values from template
echo -e "${BLUE}📦 Generating Helm override values...${NC}"
envsubst < ./loki/loki-values-template.yaml > ./loki/loki-override-values.yaml
envsubst < ./mimir/mimir-values-template.yaml > ./mimir/mimir-override-values.yaml
envsubst < ./tempo/tempo-values-template.yaml > ./tempo/tempo-override-values.yaml
envsubst < ./pyroscope/pyroscope-values-template.yaml > ./pyroscope/pyroscope-override-values.yaml

echo -e "${GREEN}📄 Generated override YAMLs:${NC}"
ls -1 ./loki/*override-values.yaml ./mimir/*override-values.yaml ./tempo/*override-values.yaml ./pyroscope/*override-values.yaml


### -------------------------------------------------------------
# Final Summary
echo ""
echo -e "${GREEN}✅ IAM Role ARNs created for usage:${NC}"
echo "  Loki     : $loki_role_arn"
echo "  Mimir    : $mimir_role_arn"
echo "  Tempo    : $tempo_role_arn"
echo "  Pyroscope: $pyroscope_role_arn"

echo -e "${GREEN}\n🎉 All AWS resources created or verified."
echo -e "🚀 You can now install Helm charts using the generated override files.${NC}"
