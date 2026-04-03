#!/usr/bin/env bash
#
# Deletes AWS resources created by script.sh (S3 buckets + IRSA IAM roles/policies).
# Use --dry-run to only list what exists and what would be removed.
# Use --from-state to load bucket/cluster names from .observability-poc-aws.state (written by script.sh).
#
# Non-interactive: OBSERVABILITY_AWS_CLEANUP_CONFIRM=DELETE ./cleanup-aws.sh ...
#
set -euo pipefail
export AWS_PAGER=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STATE_FILE="${OBSERVABILITY_STATE_FILE:-./.observability-poc-aws.state}"

IAM_ROLES=(
  LokiServiceAccountRole
  MimirServiceAccountRole
  TempoServiceAccountRole
  PyroscopeServiceAccountRole
)

IAM_POLICIES=(
  LokiS3AccessPolicy
  MimirS3AccessPolicy
  TempoS3AccessPolicy
  PyroscopeS3AccessPolicy
)

DRY_RUN=0
FROM_STATE=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --from-state) FROM_STATE=1 ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--from-state]"
      echo ""
      echo "  --dry-run     Show S3 buckets and IAM roles/policies that exist; do not delete."
      echo "  --from-state  Load names from ${STATE_FILE} (created by script.sh)."
      echo ""
      echo "Without --from-state, you are prompted for the same cluster/region/bucket inputs as script.sh."
      echo "Confirmation: type DELETE when prompted, or set OBSERVABILITY_AWS_CLEANUP_CONFIRM=DELETE"
      exit 0
      ;;
  esac
done

prompt_input() {
  local var_name="$1"
  local prompt="$2"
  local default="$3"
  read -r -p "$(echo -e "${BLUE}${prompt} [${default}]: ${NC}")" input
  input="${input:-$default}"
  export $var_name="$input"
}

bucket_exists() {
  aws s3api head-bucket --bucket "$1" 2>/dev/null
}

role_exists() {
  aws iam get-role --role-name "$1" >/dev/null 2>&1
}

policy_arn_for_name() {
  local name="$1"
  aws iam list-policies --scope Local --query "Policies[?PolicyName=='${name}'].Arn | [0]" --output text 2>/dev/null | grep -E '^arn:' || true
}

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  observability-hub — AWS POC cleanup${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${GREEN}Mode: DRY-RUN (no deletes will be performed)${NC}"
else
  echo -e "${RED}Mode: DESTRUCTIVE (resources will be deleted after confirmation)${NC}"
fi
echo ""

if [[ "$FROM_STATE" -eq 1 ]]; then
  if [[ ! -f "$STATE_FILE" ]]; then
    echo -e "${RED}State file not found: ${STATE_FILE}${NC}"
    echo "Run ./script.sh first (it writes this file), or omit --from-state to enter names manually."
    exit 1
  fi
  echo -e "${BLUE}Loading state from ${STATE_FILE}${NC}"
  # shellcheck source=/dev/null
  set -a
  source "$STATE_FILE"
  set +a
  if [[ -z "${env_loki_chunk_bucket:-}" || -z "${region_name:-}" ]]; then
    echo -e "${RED}State file is missing required keys (env_loki_chunk_bucket, region_name, ...).${NC}"
    exit 1
  fi
  # Older state files omit s3_bucket_region; buckets were created in cluster region.
  s3_bucket_region="${s3_bucket_region:-$region_name}"
  BUCKETS=(
    "$env_loki_chunk_bucket"
    "$env_loki_ruler_bucket"
    "$env_mimir_chunk_bucket"
    "$env_mimir_ruler_bucket"
    "$env_tempo_chunk_bucket"
    "$env_pyroscope_chunk_bucket"
  )
else
  echo -e "${BLUE}Enter the same naming you used with script.sh (full bucket names = cluster-lower + suffix).${NC}"
  prompt_input cluster_name "EKS cluster name" "my-cluster"
  export cluster_name_lower
  cluster_name_lower=$(echo "$cluster_name" | tr '[:upper:]' '[:lower:]')
  prompt_input region_name "AWS region (EKS cluster, for reference)" "ap-southeast-1"
  prompt_input s3_bucket_region "AWS region where observability S3 buckets exist" "${region_name}"

  prompt_input loki_chunk_bucket "Loki chunks bucket suffix (full name = cluster-suffix)" "loki-chunks"
  prompt_input loki_ruler_bucket "Loki ruler bucket suffix" "loki-ruler"
  prompt_input mimir_chunk_bucket "Mimir chunks bucket suffix" "mimir-chunks"
  prompt_input mimir_ruler_bucket "Mimir ruler bucket suffix" "mimir-ruler"
  prompt_input tempo_chunk_bucket "Tempo chunks bucket suffix" "tempo-chunks"
  prompt_input pyroscope_chunk_bucket "Pyroscope chunks bucket suffix" "pyroscope-chunks"

  env_loki_chunk_bucket="${cluster_name_lower}-${loki_chunk_bucket}"
  env_loki_ruler_bucket="${cluster_name_lower}-${loki_ruler_bucket}"
  env_mimir_chunk_bucket="${cluster_name_lower}-${mimir_chunk_bucket}"
  env_mimir_ruler_bucket="${cluster_name_lower}-${mimir_ruler_bucket}"
  env_tempo_chunk_bucket="${cluster_name_lower}-${tempo_chunk_bucket}"
  env_pyroscope_chunk_bucket="${cluster_name_lower}-${pyroscope_chunk_bucket}"

  BUCKETS=(
    "$env_loki_chunk_bucket"
    "$env_loki_ruler_bucket"
    "$env_mimir_chunk_bucket"
    "$env_mimir_ruler_bucket"
    "$env_tempo_chunk_bucket"
    "$env_pyroscope_chunk_bucket"
  )
fi

s3_bucket_region="${s3_bucket_region:-$region_name}"

account_id=$(aws sts get-caller-identity --query "Account" --output text)

echo ""
echo -e "${CYAN}── S3 buckets (script.sh naming) ──${NC}"
echo -e "Account: ${YELLOW}${account_id}${NC}  EKS/cluster region: ${YELLOW}${region_name}${NC}  S3 bucket region: ${YELLOW}${s3_bucket_region}${NC}"
echo ""
declare -a BUCKET_STATUS=()
for b in "${BUCKETS[@]}"; do
  if bucket_exists "$b"; then
    echo -e "  ${GREEN}EXISTS${NC}  s3://${b}"
    BUCKET_STATUS+=("yes")
  else
    echo -e "  ${YELLOW}absent${NC} s3://${b}"
    BUCKET_STATUS+=("no")
  fi
done

echo ""
echo -e "${CYAN}── IAM roles (detach all managed + inline, then delete) ──${NC}"
declare -a ROLE_STATUS=()
for r in "${IAM_ROLES[@]}"; do
  if role_exists "$r"; then
    echo -e "  ${GREEN}EXISTS${NC}  ${r}"
    ROLE_STATUS+=("yes")
  else
    echo -e "  ${YELLOW}absent${NC} ${r}"
    ROLE_STATUS+=("no")
  fi
done

echo ""
echo -e "${CYAN}── IAM customer-managed policies (delete after roles) ──${NC}"
declare -a POLICY_STATUS=()
declare -a POLICY_ARNS=()
for p in "${IAM_POLICIES[@]}"; do
  arn="$(policy_arn_for_name "$p")"
  if [[ -n "$arn" ]]; then
    echo -e "  ${GREEN}EXISTS${NC}  ${p}"
    echo -e "           ${arn}"
    POLICY_STATUS+=("yes")
    POLICY_ARNS+=("$arn")
  else
    echo -e "  ${YELLOW}absent${NC} ${p}"
    POLICY_STATUS+=("no")
    POLICY_ARNS+=("")
  fi
done

echo ""
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${GREEN}Dry-run complete. No changes made.${NC}"
  echo -e "Run without ${BLUE}--dry-run${NC} to delete (you will confirm with typing ${RED}DELETE${NC})."
  exit 0
fi

# Nothing to do?
any_bucket=0
any_role=0
any_policy=0
for s in "${BUCKET_STATUS[@]}"; do [[ "$s" == "yes" ]] && any_bucket=1; done
for s in "${ROLE_STATUS[@]}"; do [[ "$s" == "yes" ]] && any_role=1; done
for s in "${POLICY_STATUS[@]}"; do [[ "$s" == "yes" ]] && any_policy=1; done
if [[ "$any_bucket" -eq 0 && "$any_role" -eq 0 && "$any_policy" -eq 0 ]]; then
  echo -e "${YELLOW}Nothing to delete (no matching buckets, roles, or policies found).${NC}"
  exit 0
fi

echo -e "${RED}This will permanently remove the EXISTING items listed above:${NC}"
echo -e "  • S3: empty buckets with ${BLUE}aws s3 rb s3://... --force${NC}"
echo -e "  • IAM: detach policies from roles, delete roles, then delete the four customer-managed policies"
echo ""

if [[ "${OBSERVABILITY_AWS_CLEANUP_CONFIRM:-}" == "DELETE" ]]; then
  echo -e "${YELLOW}OBSERVABILITY_AWS_CLEANUP_CONFIRM=DELETE — skipping interactive confirm.${NC}"
else
  read -r -p "$(echo -e "Type ${RED}DELETE${NC} to proceed (anything else aborts): ")" confirm
  if [[ "$confirm" != "DELETE" ]]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 1
  fi
fi

detach_all_from_role() {
  local role="$1"
  role_exists "$role" || return 0
  echo -e "${BLUE}Detaching managed policies from ${role}...${NC}"
  local arns
  arns=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || true)
  for arn in $arns; do
    [[ -z "$arn" || "$arn" == "None" ]] && continue
    echo -e "  detach ${arn}"
    aws iam detach-role-policy --role-name "$role" --policy-arn "$arn"
  done
  local inlines
  inlines=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames[]' --output text 2>/dev/null || true)
  for pname in $inlines; do
    [[ -z "$pname" || "$pname" == "None" ]] && continue
    echo -e "  delete inline policy ${pname}"
    aws iam delete-role-policy --role-name "$role" --policy-name "$pname"
  done
}

delete_role_if_exists() {
  local role="$1"
  role_exists "$role" || return 0
  echo -e "${BLUE}Deleting role ${role}...${NC}"
  aws iam delete-role --role-name "$role"
  echo -e "${GREEN}  deleted ${role}${NC}"
}

delete_policy_if_exists() {
  local arn="$1"
  [[ -z "$arn" ]] && return 0
  echo -e "${BLUE}Deleting policy ${arn}...${NC}"
  if aws iam delete-policy --policy-arn "$arn" 2>/dev/null; then
    echo -e "${GREEN}  deleted${NC}"
  else
    echo -e "${YELLOW}  could not delete (still attached elsewhere or already removed?)${NC}"
  fi
}

echo ""
echo -e "${CYAN}── Deleting IAM roles (after detach) ──${NC}"
for r in "${IAM_ROLES[@]}"; do
  detach_all_from_role "$r"
done
for r in "${IAM_ROLES[@]}"; do
  delete_role_if_exists "$r"
done

echo ""
echo -e "${CYAN}── Deleting IAM policies ──${NC}"
for arn in "${POLICY_ARNS[@]}"; do
  delete_policy_if_exists "$arn"
done

echo ""
echo -e "${CYAN}── Deleting S3 buckets ──${NC}"
for b in "${BUCKETS[@]}"; do
  if bucket_exists "$b"; then
    echo -e "${BLUE}Removing s3://${b} (including objects)...${NC}"
    aws s3 rb "s3://${b}" --force --region "$s3_bucket_region" || aws s3 rb "s3://${b}" --force
    echo -e "${GREEN}  removed s3://${b}${NC}"
  fi
done

echo ""
echo -e "${GREEN}✅ AWS POC cleanup finished.${NC}"
echo -e "Helm/Kubernetes workloads are unchanged — run ${BLUE}make uninstall-all${NC} / ${BLUE}make uninstall-cleanup${NC} separately if needed."
echo -e "Local files (policy JSON, loki-override-values.yaml, state file) were not deleted."
