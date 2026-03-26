# Tests

This folder contains reproducible verification checks for the SecureDocs AWS project.
All tests use synthetic, public-safe data and no real customer data or credentials.

## Scope

- API behavior and owner-based access control (e.g., requests for one user must not leak another's data).
- Infrastructure verification for security controls (e.g., IAM policies, logging, network boundaries).
- Script-based checks for portfolio validation (e.g., drift checks, pre-push checks).

## How to run

- Run end-to-end verification scripts from the repository root:

```bash
sh scripts/verification/verify_secure_docs.sh
sh scripts/verification/test_secure_docs.sh
```

- Use environment-specific values from `terraform output` for the target environment (e.g., `infra/environments/dev`).
- Confirm expected success paths and denial paths (e.g., cross-user access must return 403).

## Pass criteria

- All HTTP-level tests return expected status codes and response shapes.
- No Terraform plan or apply would introduce unintended drift.
- No secrets or sensitive files are detected by `scripts/security/check_secrets.sh`.

## Notes

- No real customer data is used.
- Test artifacts (logs, fixtures, outputs) must remain synthetic and safe for public repositories.
