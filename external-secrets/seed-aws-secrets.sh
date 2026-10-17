#!/usr/bin/env bash
# Seed AWS Secrets Manager with observability-hub basic-auth material.
# Does NOT write .htpasswd (or any secret) into the git workspace.
#
# Prerequisites: aws CLI, jq, and either `htpasswd` (apache2-utils / httpd-tools)
#                or Python 3 with passlib (fallback).
#
# Usage:
#   ENVIRONMENT=dev ./external-secrets/seed-aws-secrets.sh
#   ENVIRONMENT=prod REGION=us-east-1 ./external-secrets/seed-aws-secrets.sh
#
# ENVIRONMENT (prod | stage | dev) picks which writers Alloy / Prometheus / Tempo get. The gateways
# derive the tenant from the basic-auth user. All passwords are random and rotate on every run.
#
# Loki gateway (loki/loki-values-template.yaml httpSnippet):
#   loki-writer-<env>  → tenant <env>       (Alloy in that environment)
#   loki-canary        → tenant canary
#   grafana-reader     → env tenants only   (Grafana datasources)
# Mimir gateway (mimir/mimir-values-template.yaml nginx.nginxConfig.file):
#   mimir-writer-<env> → tenant <env>       (Alloy, Prometheus, Tempo metrics-generator)
#   loki-ruler         → one env tenant     (Loki ruler sends the rule's tenant)
#   grafana-reader     → env tenants or anonymous (pre-multitenancy history)
# Grafana local admin (observability-hub/grafana-admin): run `make grafana-admin-reset` afterwards,
# because Grafana only reads it when its database is created.
#
set -euo pipefail

REGION="${REGION:-${AWS_REGION:-}}"
PREFIX="${ESO_SECRET_PREFIX:-observability-hub}"
ENVIRONMENT="${ENVIRONMENT:-}"
ENVIRONMENTS=(prod stage dev)

case "${ENVIRONMENT}" in
  prod|stage|dev) ;;
  *) echo "ERROR: set ENVIRONMENT to prod, stage or dev (got '${ENVIRONMENT}')" >&2; exit 1 ;;
esac

if [[ -z "${REGION}" ]]; then
  # Prefer live discovery (same as Makefile) over a local state file.
  if [[ -x ./scripts/resolve-cluster-env.sh ]]; then
    REGION="$(./scripts/resolve-cluster-env.sh region 2>/dev/null || true)"
  fi
fi
if [[ -z "${REGION}" ]]; then
  echo "ERROR: set REGION or AWS_REGION (or point kubectl at an EKS cluster / configure aws CLI region)" >&2
  exit 1
fi

rand_password() {
  openssl rand -base64 24 | tr -d '/+=' | head -c 32
}

htpasswd_line() {
  local user="$1" pass="$2"
  if command -v htpasswd >/dev/null 2>&1; then
    # apr1 — compatible with Loki/Mimir nginx auth_basic
    htpasswd -nb "$user" "$pass" | tr -d '\n'
    return
  fi
  python3 - "$user" "$pass" <<'PY'
import crypt, sys
user, password = sys.argv[1], sys.argv[2]
# glibc crypt supports apr1 when available
try:
    hashed = crypt.crypt(password, crypt.METHOD_MD5)
except Exception:
    hashed = crypt.crypt(password)
if not hashed:
    sys.exit("python crypt failed; install apache2-utils (htpasswd)")
print(f"{user}:{hashed}", end="")
PY
}

upsert_sm_json() {
  local name="$1" json="$2"
  if AWS_PAGER="" aws secretsmanager describe-secret --region "$REGION" --secret-id "$name" >/dev/null 2>&1; then
    AWS_PAGER="" aws secretsmanager put-secret-value \
      --region "$REGION" --secret-id "$name" --secret-string "$json" >/dev/null
    echo "🔄 Updated $name"
  else
    AWS_PAGER="" aws secretsmanager create-secret \
      --region "$REGION" --name "$name" --secret-string "$json" >/dev/null
    echo "📌 Created $name"
  fi
}

user_pass_json() {
  jq -n --arg username "$1" --arg password "$2" '{username:$username,password:$password}'
}

CANARY_USER="loki-canary"
CANARY_PASS="$(rand_password)"
READER_USER="grafana-reader"
READER_PASS="$(rand_password)"
MIMIR_READER_PASS="$(rand_password)"
GRAFANA_ADMIN_PASS="$(rand_password)"
MIMIR_RULER_USER="loki-ruler"
MIMIR_RULER_PASS="$(rand_password)"

LOKI_HTPASSWD="$(htpasswd_line "$CANARY_USER" "$CANARY_PASS")"
LOKI_HTPASSWD+=$'\n'"$(htpasswd_line "$READER_USER" "$READER_PASS")"
for env in "${ENVIRONMENTS[@]}"; do
  pass="$(rand_password)"
  LOKI_HTPASSWD+=$'\n'"$(htpasswd_line "loki-writer-${env}" "$pass")"
  upsert_sm_json "${PREFIX}/loki-writer-${env}" "$(user_pass_json "loki-writer-${env}" "$pass")"
  if [[ "$env" == "$ENVIRONMENT" ]]; then
    LOKI_USER="loki-writer-${env}"
    LOKI_PASS="$pass"
  fi
done

MIMIR_HTPASSWD="$(htpasswd_line "$READER_USER" "$MIMIR_READER_PASS")"
MIMIR_HTPASSWD+=$'\n'"$(htpasswd_line "$MIMIR_RULER_USER" "$MIMIR_RULER_PASS")"
for env in "${ENVIRONMENTS[@]}"; do
  pass="$(rand_password)"
  MIMIR_HTPASSWD+=$'\n'"$(htpasswd_line "mimir-writer-${env}" "$pass")"
  upsert_sm_json "${PREFIX}/mimir-writer-${env}" "$(user_pass_json "mimir-writer-${env}" "$pass")"
  if [[ "$env" == "$ENVIRONMENT" ]]; then
    MIMIR_USER="mimir-writer-${env}"
    MIMIR_PASS="$pass"
  fi
done

upsert_sm_json "${PREFIX}/loki-basic-auth" \
  "$(jq -n --arg htpasswd "$LOKI_HTPASSWD" '{htpasswd:$htpasswd}')"

upsert_sm_json "${PREFIX}/mimir-basic-auth" \
  "$(jq -n --arg htpasswd "$MIMIR_HTPASSWD" '{htpasswd:$htpasswd}')"

upsert_sm_json "${PREFIX}/loki-canary" "$(user_pass_json "$CANARY_USER" "$CANARY_PASS")"

upsert_sm_json "${PREFIX}/loki-grafana-reader" "$(user_pass_json "$READER_USER" "$READER_PASS")"

upsert_sm_json "${PREFIX}/mimir-grafana-reader" "$(user_pass_json "$READER_USER" "$MIMIR_READER_PASS")"

upsert_sm_json "${PREFIX}/mimir-loki-ruler" "$(user_pass_json "$MIMIR_RULER_USER" "$MIMIR_RULER_PASS")"

upsert_sm_json "${PREFIX}/grafana-admin" "$(user_pass_json "admin" "$GRAFANA_ADMIN_PASS")"

upsert_sm_json "${PREFIX}/alloy-remote-credentials" \
  "$(jq -n \
    --arg loki_gateway_username "$LOKI_USER" \
    --arg loki_gateway_password "$LOKI_PASS" \
    --arg mimir_remote_write_username "$MIMIR_USER" \
    --arg mimir_remote_write_password "$MIMIR_PASS" \
    '{
      loki_gateway_username:$loki_gateway_username,
      loki_gateway_password:$loki_gateway_password,
      mimir_remote_write_username:$mimir_remote_write_username,
      mimir_remote_write_password:$mimir_remote_write_password
    }')"

# Prometheus + Tempo metrics-generator remote_write (ExternalSecrets in monitoring / tempo).
upsert_sm_json "${PREFIX}/mimir-remote-write" "$(user_pass_json "$MIMIR_USER" "$MIMIR_PASS")"

echo ""
echo "✅ Seeded AWS Secrets Manager in ${REGION} (prefix ${PREFIX}/)."
echo "   Plaintext passwords are only shown below — store them in your vault; they are not written to disk."
echo ""
echo "   Alloy loki_gateway_* (tenant ${ENVIRONMENT}):"
echo "     user=${LOKI_USER}"
echo "     pass=${LOKI_PASS}"
echo "   Other users (canary, grafana-reader, loki-ruler, *-writer-<env>): see ${PREFIX}/loki-* and ${PREFIX}/mimir-* in Secrets Manager."
echo "   Mimir remote_write for Alloy / Prometheus / Tempo (tenant ${ENVIRONMENT}):"
echo "     user=${MIMIR_USER}"
echo "     pass=${MIMIR_PASS}"
echo ""
echo "   Grafana local admin: user=admin, password in ${PREFIX}/grafana-admin."
echo ""
echo "Next: make eso-apply             # ClusterSecretStore + ExternalSecrets"
echo "      make grafana-admin-reset   # existing Grafana: apply the new admin password"
