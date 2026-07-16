#!/usr/bin/env bash
# Resolve CLUSTER_NAME and REGION for Makefile / tooling.
#
# Priority (first match wins):
#   1. Explicit environment
#        CLUSTER_NAME or CLUSTER
#        AWS_REGION, else AWS_DEFAULT_REGION, else REGION
#   2. Live cluster / AWS discovery
#        kubectl current-context (EKS ARN) or node labels / providerID
#        aws configure get region
#   3. Legacy .observability-poc-aws.state (deprecated — warning on stderr)
#
# Usage:
#   ./scripts/resolve-cluster-env.sh              # KEY=value lines (+ SOURCE_*)
#   ./scripts/resolve-cluster-env.sh cluster      # cluster name only
#   ./scripts/resolve-cluster-env.sh region       # region only
#   ./scripts/resolve-cluster-env.sh --check      # exit 1 if either empty
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="${OBSERVABILITY_STATE_FILE:-${REPO_ROOT}/.observability-poc-aws.state}"

CLUSTER_VAL=""
REGION_VAL=""
SOURCE_CLUSTER="missing"
SOURCE_REGION="missing"

trim() {
  local s="${1-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s//$'\r'/}"
}

from_state() {
  local key="$1" v
  [[ -f "${STATE_FILE}" ]] || return 1
  v="$(grep -E "^${key}=" "${STATE_FILE}" 2>/dev/null | cut -d= -f2- | head -1 || true)"
  v="$(trim "${v}")"
  [[ -n "${v}" ]] || return 1
  printf '%s' "${v}"
}

discover_cluster_from_kubectl() {
  command -v kubectl >/dev/null 2>&1 || return 1
  local ctx arn name
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  [[ -n "${ctx}" ]] || return 1

  arn="${ctx}"
  if [[ "${arn}" != arn:aws:eks:* ]]; then
    arn="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || true)"
  fi
  if [[ "${arn}" == arn:aws:eks:*:*:cluster/* ]]; then
    printf '%s' "${arn##*/}"
    return 0
  fi

  name="$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.eks\.amazonaws\.com/cluster-name}' 2>/dev/null || true)"
  if [[ -z "${name}" ]]; then
    name="$(kubectl get nodes -o jsonpath='{.items[0].metadata.labels.alpha\.eksctl\.io/cluster-name}' 2>/dev/null || true)"
  fi
  name="$(trim "${name}")"
  [[ -n "${name}" ]] || return 1
  printf '%s' "${name}"
}

discover_region_from_kubectl() {
  command -v kubectl >/dev/null 2>&1 || return 1
  local ctx arn pid zone
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  arn="${ctx}"
  if [[ "${arn}" != arn:aws:eks:* ]]; then
    arn="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || true)"
  fi
  if [[ "${arn}" == arn:aws:eks:*:*:cluster/* ]]; then
    printf '%s' "$(echo "${arn}" | cut -d: -f4)"
    return 0
  fi

  pid="$(kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' 2>/dev/null || true)"
  if [[ "${pid}" == aws:///* ]]; then
    zone="$(echo "${pid}" | cut -d/ -f4)"
    if [[ "${zone}" =~ ^([a-z]{2}-[a-z]+-[0-9]+)[a-z]$ ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi
  return 1
}

discover_region_from_aws() {
  command -v aws >/dev/null 2>&1 || return 1
  local r
  r="$(AWS_PAGER="" aws configure get region 2>/dev/null || true)"
  r="$(trim "${r}")"
  [[ -n "${r}" ]] || return 1
  printf '%s' "${r}"
}

resolve_all() {
  local v
  v="$(trim "${CLUSTER_NAME:-${CLUSTER:-}}")"
  if [[ -n "${v}" ]]; then
    CLUSTER_VAL="${v}"
    SOURCE_CLUSTER="env"
  elif v="$(discover_cluster_from_kubectl 2>/dev/null)"; then
    CLUSTER_VAL="$(trim "${v}")"
    SOURCE_CLUSTER="kubectl"
  elif v="$(from_state cluster_name)"; then
    CLUSTER_VAL="${v}"
    SOURCE_CLUSTER="state-file(deprecated)"
    echo "WARN: CLUSTER_NAME resolved from ${STATE_FILE} (deprecated). Prefer: export CLUSTER_NAME=… or an EKS kubecontext." >&2
  else
    CLUSTER_VAL=""
    SOURCE_CLUSTER="missing"
  fi

  v="$(trim "${AWS_REGION:-${AWS_DEFAULT_REGION:-${REGION:-}}}")"
  if [[ -n "${v}" ]]; then
    REGION_VAL="${v}"
    SOURCE_REGION="env"
  elif v="$(discover_region_from_kubectl 2>/dev/null)"; then
    REGION_VAL="$(trim "${v}")"
    SOURCE_REGION="kubectl"
  elif v="$(discover_region_from_aws 2>/dev/null)"; then
    REGION_VAL="$(trim "${v}")"
    SOURCE_REGION="aws-cli"
  elif v="$(from_state region_name)"; then
    REGION_VAL="${v}"
    SOURCE_REGION="state-file(deprecated)"
    echo "WARN: REGION resolved from ${STATE_FILE} (deprecated). Prefer: export AWS_REGION=… or REGION=…." >&2
  else
    REGION_VAL=""
    SOURCE_REGION="missing"
  fi
}

resolve_all

case "${1:-}" in
  cluster)
    printf '%s\n' "${CLUSTER_VAL}"
    ;;
  region)
    printf '%s\n' "${REGION_VAL}"
    ;;
  --check)
    if [[ -z "${CLUSTER_VAL}" || -z "${REGION_VAL}" ]]; then
      echo "ERROR: could not resolve CLUSTER_NAME and/or REGION." >&2
      echo "  Export CLUSTER_NAME and AWS_REGION (or REGION), or point kubectl at an EKS cluster." >&2
      echo "  CLUSTER_NAME source=${SOURCE_CLUSTER} value='${CLUSTER_VAL}'" >&2
      echo "  REGION       source=${SOURCE_REGION} value='${REGION_VAL}'" >&2
      exit 1
    fi
    echo "CLUSTER_NAME=${CLUSTER_VAL} (from ${SOURCE_CLUSTER})"
    echo "REGION=${REGION_VAL} (from ${SOURCE_REGION})"
    ;;
  "")
    echo "CLUSTER_NAME=${CLUSTER_VAL}"
    echo "REGION=${REGION_VAL}"
    echo "CLUSTER=${CLUSTER_VAL}"
    echo "AWS_REGION=${REGION_VAL}"
    echo "SOURCE_CLUSTER=${SOURCE_CLUSTER}"
    echo "SOURCE_REGION=${SOURCE_REGION}"
    ;;
  *)
    echo "Usage: $0 [cluster|region|--check]" >&2
    exit 2
    ;;
esac
