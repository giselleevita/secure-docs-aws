# Tests

This folder contains reproducible verification checks for the SecureDocs AWS project.
All tests use synthetic, public-safe data and no real customer data or credentials.

## Scope

- API behavior and owner-based access control (e.g., requests for one user must not leak another's data).
- Infrastructure verification for security controls (e.g., IAM policies, logging, network boundaries).
- Script-based checks for repository validation (e.g., drift checks, pre-push checks).

## How to run

Verification is manual against a deployed environment. Read the endpoint,
Cognito pool, and bucket values from `terraform output` for the target
environment (e.g. `infra/environments/dev`), obtain a Cognito JWT for a test
user, then exercise the API with `curl`:

```bash
# happy path — own file
curl -H "Authorization: Bearer $JWT" "$API/files"            # 200, lists caller's files
# denial path — another user's object
curl -H "Authorization: Bearer $JWT" "$API/files/$OTHER_KEY" # 403

# repo hygiene check (no deploy needed)
sh scripts/security/check_secrets.sh
```
- Confirm expected success paths and denial paths (e.g., cross-user access must return 403).

## Pass criteria

- All HTTP-level tests return expected status codes and response shapes.
- No Terraform plan or apply would introduce unintended drift.
- No secrets or sensitive files are detected by `scripts/security/check_secrets.sh`.

## Notes

- No real customer data is used.
- Test artifacts (logs, fixtures, outputs) must remain synthetic and safe for public repositories.
