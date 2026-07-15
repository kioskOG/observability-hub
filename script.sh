#!/usr/bin/env bash
# DEPRECATED: AWS S3 + IRSA live under the existing Terragrunt layout:
#
#   S3  : terragrunt/infrastructure-live/accounts/mlops/us-east-2/s3/millenniumfalcon-*
#   IAM : terragrunt/infrastructure-live/accounts/mlops/global/iam/role/
#
# Prefer: make aws-apply
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"
exec make aws-apply
