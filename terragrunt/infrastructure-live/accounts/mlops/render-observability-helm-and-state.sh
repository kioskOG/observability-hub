#!/usr/bin/env bash
# Render Helm *-override-values.yaml from the existing Terragrunt layout.
# This script consumes Terraform outputs directly and never queries AWS CLI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}
require_cmd terragrunt
require_cmd envsubst
require_cmd jq

# Extract outputs from the global IAM role module
echo "🔍 Extracting IAM Role ARNs from Terragrunt..."
cd "${SCRIPT_DIR}/global/iam/role"
TG_OUT=$(terragrunt output -json)

export loki_role_arn=$(echo "$TG_OUT" | jq -r '.iam_role_arns.value.LokiServiceAccountRole')
export mimir_role_arn=$(echo "$TG_OUT" | jq -r '.iam_role_arns.value.MimirServiceAccountRole')
export tempo_role_arn=$(echo "$TG_OUT" | jq -r '.iam_role_arns.value.TempoServiceAccountRole')
export pyroscope_role_arn=$(echo "$TG_OUT" | jq -r '.iam_role_arns.value.PyroscopeServiceAccountRole')
export eso_role_arn=$(echo "$TG_OUT" | jq -r '.iam_role_arns.value.ESOControllerServiceAccountRole')

echo "🔍 Extracting Grafana OIDC Endpoints from Terragrunt..."
cd "${SCRIPT_DIR}/us-east-2/keycloak/grafana"
GRAFANA_OIDC_OUT=$(terragrunt output -json)
export grafana_oidc_client_id=$(echo "$GRAFANA_OIDC_OUT" | jq -r '.client.value.client_id')
export grafana_oidc_auth_url=$(echo "$GRAFANA_OIDC_OUT" | jq -r '.oidc.value.authorization_endpoint')
export grafana_oidc_token_url=$(echo "$GRAFANA_OIDC_OUT" | jq -r '.oidc.value.token_endpoint')
export grafana_oidc_api_url=$(echo "$GRAFANA_OIDC_OUT" | jq -r '.oidc.value.userinfo_endpoint')
export grafana_oidc_logout_url=$(echo "$GRAFANA_OIDC_OUT" | jq -r '.oidc.value.end_session_endpoint')

cd "${SCRIPT_DIR}"

CLUSTER_NAME="${CLUSTER_NAME:-${OBSERVABILITY_CLUSTER_NAME:-millenniumfalcon}}"
CLUSTER_LOWER="$(echo "${CLUSTER_NAME}" | tr '[:upper:]' '[:lower:]')"
REGION_NAME="${AWS_REGION:-${REGION:-${OBSERVABILITY_CLUSTER_REGION:-us-east-2}}}"
S3_BUCKET_REGION="${OBSERVABILITY_S3_REGION:-${REGION_NAME}}"

export s3_bucket_region="${S3_BUCKET_REGION}"
export env_loki_chunk_bucket="${CLUSTER_LOWER}-loki-chunks"
export env_loki_ruler_bucket="${CLUSTER_LOWER}-loki-ruler"
export env_mimir_chunk_bucket="${CLUSTER_LOWER}-mimir-chunks"
export env_mimir_ruler_bucket="${CLUSTER_LOWER}-mimir-ruler"
export env_tempo_chunk_bucket="${CLUSTER_LOWER}-tempo-chunks"
export env_pyroscope_chunk_bucket="${CLUSTER_LOWER}-pyroscope-chunks"

OBSERVABILITY_ENVSUBST_FORMAT='${s3_bucket_region} ${env_loki_chunk_bucket} ${env_loki_ruler_bucket} ${loki_role_arn} ${env_mimir_ruler_bucket} ${env_mimir_chunk_bucket} ${mimir_role_arn} ${env_tempo_chunk_bucket} ${tempo_role_arn} ${env_pyroscope_chunk_bucket} ${pyroscope_role_arn} ${grafana_oidc_client_id} ${grafana_oidc_auth_url} ${grafana_oidc_token_url} ${grafana_oidc_api_url} ${grafana_oidc_logout_url}'

echo "📦 Rendering Helm temporary override values into ${REPO_ROOT}"
# Generate temporary rendered files instead of mutating tracked files
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/loki/loki-values-template.yaml" > "${REPO_ROOT}/loki/loki-override-values.rendered.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/mimir/mimir-values-template.yaml" > "${REPO_ROOT}/mimir/mimir-override-values.rendered.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/tempo/tempo-values-template.yaml" > "${REPO_ROOT}/tempo/tempo-override-values.rendered.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/pyroscope/pyroscope-values-template.yaml" > "${REPO_ROOT}/pyroscope/pyroscope-override-values.rendered.yaml"
envsubst "${OBSERVABILITY_ENVSUBST_FORMAT}" < "${REPO_ROOT}/kube-prometheus-stack/prometheus-values-template.yaml" > "${REPO_ROOT}/kube-prometheus-stack/prometheus-override-values.rendered.yaml"

echo "✅ IRSA role ARNs:"
echo "  Loki      : ${loki_role_arn}"
echo "  Mimir     : ${mimir_role_arn}"
echo "  Tempo     : ${tempo_role_arn}"
echo "  Pyroscope : ${pyroscope_role_arn}"
echo "  ESO       : ${eso_role_arn}"
