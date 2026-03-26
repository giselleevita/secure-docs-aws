# Security Policy

## Project Scope

This is a public learning project for AWS security architecture and secure coding practices.
It is not a production service and is not intended to handle real customer data.

### In scope

- Terraform and infrastructure configurations in `infra/`.
- Application source code in `app/`.
- Verification scripts and security documentation in `docs/` and `scripts/`.

### Out of scope

- Production workloads or customer environments.
- Private support channels or paid advisory services.
- External systems not explicitly modeled in the repository.

## Reporting Security Issues

To report a security issue:

1. Use the GitHub Security Report template:
   - Open a new issue and select the **Security Report** template.
2. Provide:
   - A clear description of the vulnerability.
   - Minimal, public-safe reproduction steps (no real credentials or PII).
   - Expected behavior vs actual behavior.

### What not to include

- Real credentials, private keys, or personal data.
- Links to internal or private infrastructure.

## Response Expectations

- Initial triage: within 3 business days.
- Follow-up status update: within 7 business days.
- Fix timing: based on severity and reproducibility, typically addressed in the next logical update window.

All responses will be handled in public or via GitHub issue comments, unless a private disclosure channel is explicitly agreed.
