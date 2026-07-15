#!/usr/bin/env bash
# Seed AWS Secrets Manager with observability-hub basic-auth material.
# Does NOT write .htpasswd (or any secret) into the git workspace.
#
# Prerequisites: aws CLI, jq, and either `htpasswd` (apache2-utils / httpd-tools)
#                or Python 3 with passlib (fallback).
#
# Usage:
#   ./external-secrets/seed-aws-secrets.sh
#   REGION=us-east-1 ./external-secrets/seed-aws-secrets.sh
#
# Optional overrides (otherwise random passwords are generated):
#   LOKI_GATEWAY_USER / LOKI_GATEWAY_PASSWORD
#   MIMIR_GATEWAY_USER / MIMIR_GATEWAY_PASSWORD
#
set -euo pipefail

REGION="${REGION:-${AWS_REGION:-}}"
PREFIX="${ESO_SECRET_PREFIX:-observability-hub}"

if [[ -z "${REGION}" ]]; then
  if [[ -f ./.observability-poc-aws.state ]]; then
    REGION="$(grep -E '^region_name=' ./.observability-poc-aws.state | cut -d= -f2- | tr -d '\r' | head -1)"
  fi
fi
if [[ -z "${REGION}" ]]; then
  echo "ERROR: set REGION or AWS_REGION (or run script.sh so .observability-poc-aws.state has region_name)" >&2
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

LOKI_USER="${LOKI_GATEWAY_USER:-loki-canary}"
LOKI_PASS="${LOKI_GATEWAY_PASSWORD:-$(rand_password)}"
MIMIR_USER="${MIMIR_GATEWAY_USER:-mimir-nginx}"
MIMIR_PASS="${MIMIR_GATEWAY_PASSWORD:-$(rand_password)}"

LOKI_HTPASSWD="$(htpasswd_line "$LOKI_USER" "$LOKI_PASS")"
MIMIR_HTPASSWD="$(htpasswd_line "$MIMIR_USER" "$MIMIR_PASS")"

upsert_sm_json "${PREFIX}/loki-basic-auth" \
  "$(jq -n --arg htpasswd "$LOKI_HTPASSWD" '{htpasswd:$htpasswd}')"

upsert_sm_json "${PREFIX}/mimir-basic-auth" \
  "$(jq -n --arg htpasswd "$MIMIR_HTPASSWD" '{htpasswd:$htpasswd}')"

upsert_sm_json "${PREFIX}/loki-canary" \
  "$(jq -n --arg username "$LOKI_USER" --arg password "$LOKI_PASS" '{username:$username,password:$password}')"

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

upsert_sm_json "${PREFIX}/mimir-remote-write" \
  "$(jq -n --arg username "$MIMIR_USER" --arg password "$MIMIR_PASS" '{username:$username,password:$password}')"

echo ""
echo "✅ Seeded AWS Secrets Manager in ${REGION} (prefix ${PREFIX}/)."
echo "   Plaintext passwords are only shown below — store them in your vault; they are not written to disk."
echo ""
echo "   Loki gateway / canary / Alloy loki_gateway_* :"
echo "     user=${LOKI_USER}"
echo "     pass=${LOKI_PASS}"
echo "   Mimir gateway / Prometheus+Alloy mimir remote_write :"
echo "     user=${MIMIR_USER}"
echo "     pass=${MIMIR_PASS}"
echo ""
echo "Next: make eso-apply   # ClusterSecretStore + ExternalSecrets"
