#!/usr/bin/env sh

hits="$(mktemp)"
trap 'rm -f "$hits"' EXIT
: > "$hits"

git ls-files | grep -E '\.(env|tfvars|pem|key|cer|crt|p12|pfx|jks|sqlite|db|bak|zip)$|(^|/)terraform\.tfstate(\.backup)?$' >> "$hits" || true

git grep -nI -E 'AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|password|secret|token|api[-_]?key|private[-_]?key|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----' -- . >> "$hits" || true

git rev-list --all | xargs -n1 git grep -nI -E 'AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|password|secret|token|api[-_]?key|private[-_]?key|-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----' >> "$hits" || true

git grep -nI -E '[A-Za-z0-9._%+-]\+@[A-Za-z0-9.-]\+\.[A-Za-z]\{2,\}|[0-9]\{10,\}' -- . >> "$hits" || true

git grep -nI -E '\b(real|production|customer|private|confidential|phi|pii|user|patient|health|passport|ssn|mrn|national[_-]?id)\b' docs notes app infra tests >> "$hits" || true

if [ -s "$hits" ]; then
  cat "$hits"
else
  echo "No sensitive data found"
fi
