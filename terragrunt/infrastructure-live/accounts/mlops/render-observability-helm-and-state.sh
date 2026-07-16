#!/usr/bin/env bash
# Render Helm *-override-values.yaml from the existing Terragrunt layout
# (us-east-2/s3/millenniumfalcon-* + global/iam/role).
#
# Cluster / region come from the environment (or Makefile-resolved values), not a state file:
#   CLUSTER_NAME / OBSERVABILITY_CLUSTER_NAME
#   AWS_REGION / REGION / OBSERVABILITY_CLUSTER_REGION
#
# Optionally writes .observability-poc-aws.state for legacy cleanup-aws.sh --from-state
# (deprecated — prefer env + naming convention for teardown).
# Set WRITE_OBSERVABILITY_STATE=0 to skip writing that file.
#
# Does not create AWS resources — run the S3 + IAM stacks first.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# accounts/mlops → accounts → infrastructure-live → terragrunt → repo root
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
if [[ -n "${1:-}" ]]; then
  REPO_ROOT="$(cd "$1" && pwd)"
fi
if [[ ! -f "${REPO_ROOT}/Makefile" ]]; then
  echo "ERROR: repo root not found (got ${REPO_ROOT})" >&2
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}
require_cmd aws
require_cmd envsubst
require_cmd jq

ACCOUNT_ID="$(AWS_PAGER="" aws sts get-caller-identity --query Account --output text)"
CLUSTER_NAME="${CLUSTER_NAME:-${OBSERVABILITY_CLUSTER_NAME:-millenniumfalcon}}"
CLUSTER_LOWER="$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')"
REGION_NAME="${AWS_REGION:-${REGION:-${OBSERVABILITY_CLUSTER_REGION:-us-east-2}}}"
S3_BUCKET_REGION="${OBSERVABILITY_S3_REGION:-${REGION_NAME}}"

echo "ℹ️  Rendering with CLUSTER_NAME=${CLUSTER_NAME} region=${REGION_NAME} s3_region=${S3_BUCKET_REGION}"

export s3_bucket_region="${S3_BUCKET_REGION}"
export env_loki_chunk_bucket="${CLUSTER_LOWER}-loki-chunks"
export env_loki_ruler_bucket="${CLUSTER_LOWER}-loki-ruler"
export env_mimir_chunk_bucket="${CLUSTER_LOWER}-mimir-chunks"
export env_mimir_ruler_bucket="${CLUSTER_LOWER}-mimir-ruler"
export env_tempo_chunk_bucket="${CLUSTER_LOWER}-tempo-chunks"
export env_pyroscope_chunk_bucket="${CLUSTER_LOWER}-pyroscope-chunks"

role_arn() {
  local name="$1"
  AWS_PAGER="" aws iam get-role --role-name "$name" --query 'Role.Arn' --output text 2>/dev/null \
    || printf 'arn:aws:iam::%s:role/%s' "${ACCOUNT_ID}" "${name}"
}

export loki_role_arn
export mimir_role_arn
export tempo_role_arn
export pyroscope_role_arn
loki_role_arn="$(role_arn LokiServiceAccountRole)"
mimir_role_arn="$(role_arn MimirServiceAccountRole)"
tempo_role_arn="$(role_arn TempoServiceAccountRole)"
pyroscope_role_arn="$(role_arn PyroscopeServiceAccountRole)"

OBSERVABILITY_ENVSUBST_FORMAT='${s3_bucket_region} ${env_loki_chunk_bucket} ${env_loki_ruler_bucket} ${loki_role_arn} ${env_mimir_ruler_bucket} ${env_mimir_chunk_bucket} ${mimir_role_arn} ${env_tempo_chunk_bucket} ${tempo_role_arn} ${env_pyroscope_chunk_bucket} ${pyroscope_role_arn}'

echo "📦 Rendering Helm override values into ${REPO_ROOT}"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/loki/loki-values-template.yaml" > "${REPO_ROOT}/loki/loki-override-values.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/mimir/mimir-values-template.yaml" > "${REPO_ROOT}/mimir/mimir-override-values.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/tempo/tempo-values-template.yaml" > "${REPO_ROOT}/tempo/tempo-override-values.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/pyroscope/pyroscope-values-template.yaml" > "${REPO_ROOT}/pyroscope/pyroscope-override-values.yaml"

# Optional legacy inventory for cleanup-aws.sh --from-state (not used by Makefile).
if [[ "${WRITE_OBSERVABILITY_STATE:-1}" == "1" ]]; then
  STATE_FILE="${OBSERVABILITY_STATE_FILE:-${REPO_ROOT}/.observability-poc-aws.state}"
  umask 077
  cat > "${STATE_FILE}" <<EOF
# DEPRECATED optional inventory for cleanup-aws.sh --from-state.
# Makefile resolves CLUSTER_NAME/REGION from env → kubectl → aws (see scripts/resolve-cluster-env.sh).
OBSERVABILITY_STATE_VERSION=1
provision_aws=terragrunt
cluster_name=${CLUSTER_NAME}
region_name=${REGION_NAME}
s3_bucket_region=${S3_BUCKET_REGION}
cluster_name_lower=${CLUSTER_LOWER}
env_loki_chunk_bucket=${env_loki_chunk_bucket}
env_loki_ruler_bucket=${env_loki_ruler_bucket}
env_mimir_chunk_bucket=${env_mimir_chunk_bucket}
env_mimir_ruler_bucket=${env_mimir_ruler_bucket}
env_tempo_chunk_bucket=${env_tempo_chunk_bucket}
env_pyroscope_chunk_bucket=${env_pyroscope_chunk_bucket}
loki_role_arn=${loki_role_arn}
mimir_role_arn=${mimir_role_arn}
tempo_role_arn=${tempo_role_arn}
pyroscope_role_arn=${pyroscope_role_arn}
EOF
  echo "📝 Wrote optional legacy inventory ${STATE_FILE} (Makefile does not require it)"
fi

echo "✅ IRSA role ARNs:"
echo "  Loki     : ${loki_role_arn}"
echo "  Mimir    : ${mimir_role_arn}"
echo "  Tempo    : ${tempo_role_arn}"
echo "  Pyroscope: ${pyroscope_role_arn}"
