#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${SCW_ACCESS_KEY:-}" || -z "${SCW_SECRET_KEY:-}" ]]; then
  printf '%s\n' "SCW_ACCESS_KEY and SCW_SECRET_KEY must be exported before sourcing this script." >&2
  return 1 2>/dev/null || exit 1
fi

export AWS_ACCESS_KEY_ID="${SCW_ACCESS_KEY}"
export AWS_SECRET_ACCESS_KEY="${SCW_SECRET_KEY}"

export SCW_DEFAULT_PROJECT_ID="${SCW_DEFAULT_PROJECT_ID:-c1b38e1f-9d02-40a0-8e70-c1973b2862ad}"
export SCW_DEFAULT_ORGANIZATION_ID="${SCW_DEFAULT_ORGANIZATION_ID:-6397d083-70a5-440a-acf0-257c872a759a}"
export SCW_DEFAULT_REGION="${SCW_DEFAULT_REGION:-fr-par}"
export SCW_DEFAULT_ZONE="${SCW_DEFAULT_ZONE:-fr-par-1}"

printf '%s\n' "Scaleway provider and S3 backend credentials are aligned for Terraform."
