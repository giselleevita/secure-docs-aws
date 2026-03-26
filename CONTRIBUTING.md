# Contributing

Thank you for contributing to SecureDocs AWS.
This project is a learning-focused, public portfolio repo and aims to stay small, clear, and audit-friendly.

## Branch Naming

Use descriptive prefixes:

- `feat/<short-description>` - new features.
- `fix/<short-description>` - bug fixes.
- `docs/<short-description>` - documentation changes.
- `chore/<short-description>` - maintenance tasks.

Examples:

- `feat/strict-owner-boundaries`
- `fix/incorrect-403-handling`
- `docs/index-navigation`

## Pull Request Rules

- Keep PRs focused and small (single logical change).
- Explain what changed and why in the PR description.
- Update documentation (`docs/`) when architecture or behavior changes.
- Ensure all CI checks pass.

## Commit Style

Use concise, imperative commit messages:

- `Refactor IAM role patterns`
- `Add owner boundary checks in Lambda`
- `Fix 403 handling for cross-user requests`

## Mandatory Pre-push Checks

Run these checks from the repository root before pushing:

```bash
# Secrets and hygiene scan
sh scripts/security/check_secrets.sh

# Terraform formatting check
terraform -chdir=infra/environments/dev fmt -check -recursive

# Terraform init (no backend)
terraform -chdir=infra/environments/dev init -backend=false

# Terraform validate
terraform -chdir=infra/environments/dev validate

# Git status and staged diff review
git status
git diff --staged
```

Failures in any of these steps should be fixed before pushing.
