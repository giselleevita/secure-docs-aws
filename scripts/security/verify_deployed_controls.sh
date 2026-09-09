#!/usr/bin/env bash
# Read-only post-deployment checks. This script creates no resources and sends
# no requests to the application endpoint; it only queries AWS control-plane APIs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${TF_DIR:-$ROOT/infra/environments/dev}"
AWS_ARGS=()

if [[ -n "${AWS_PROFILE:-}" ]]; then
  AWS_ARGS+=(--profile "$AWS_PROFILE")
fi
if [[ -n "${AWS_REGION:-}" ]]; then
  AWS_ARGS+=(--region "$AWS_REGION")
fi

for command in aws terraform; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 2; }
done

bucket="$(terraform -chdir="$TF_DIR" output -raw bucket_name)"
echo "Verifying read-only controls for bucket: $bucket"

failures=0
check() {
  local label="$1"
  shift
  if "$@" >/dev/null; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label" >&2
    failures=$((failures + 1))
  fi
}

check "S3 versioning is enabled" \
  bash -c '[[ "$(aws "$@" s3api get-bucket-versioning --bucket "$0" --query Status --output text)" == "Enabled" ]]' \
  "$bucket" "${AWS_ARGS[@]}"

check "all S3 public-access blocks are enabled" \
  bash -c '[[ "$(aws "$@" s3api get-public-access-block --bucket "$0" --query "PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]" --output text)" == $'"'"'True\tTrue\tTrue\tTrue'"'"' ]]' \
  "$bucket" "${AWS_ARGS[@]}"

check "S3 default encryption is configured" \
  aws "${AWS_ARGS[@]}" s3api get-bucket-encryption --bucket "$bucket"

check "bucket policy public status is not public" \
  bash -c '[[ "$(aws "$@" s3api get-bucket-policy-status --bucket "$0" --query PolicyStatus.IsPublic --output text 2>/dev/null || echo False)" == "False" ]]' \
  "$bucket" "${AWS_ARGS[@]}"

if (( failures > 0 )); then
  echo "$failures control check(s) failed." >&2
  exit 1
fi

echo "All read-only deployed-storage checks passed. Do not publish account IDs, ARNs, endpoints, or command output."
