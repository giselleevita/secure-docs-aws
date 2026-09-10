# SecureDocs reviewer guide

Review this repository in ten minutes without an AWS account or any paid cloud
resources. The goal is to inspect the trust boundary and reproduce the most
important authorization checks locally.

## Start with the boundary

The service accepts identity only from API Gateway's validated Cognito JWT claim.
The client never supplies an effective `owner_id`. DynamoDB metadata records the
owner boundary before a Lambda issues a short-lived S3 URL.

Read the [threat model](security/threat-model.md), then inspect the four handlers
under `app/`.

## Reproduce the offline checks

```bash
python -m unittest discover -s tests -v
```

The tests use in-memory AWS SDK fakes and require neither AWS credentials nor a
running service. They establish that:

1. an upload ignores a client-supplied `owner_id` and uses the JWT subject;
2. a different user cannot obtain a download URL;
3. a different user cannot delete an S3 object or DynamoDB record; and
4. list results do not expose owner identifiers.

These are application-level checks, not proof of a deployed AWS account's state.
The repository's CI also runs Terraform formatting, validation, TFLint, tfsec,
credential hygiene, and these offline boundary tests on every main-branch change.

## What requires a real AWS environment

The [deployed-control script](../scripts/security/verify_deployed_controls.sh)
performs read-only checks for S3 encryption, versioning, and public access blocks
against an explicitly configured account. Do not create the optional development
stack merely to review this portfolio; GuardDuty, AWS Config, and WAF can incur
monthly charges.

The documented [verification plan](verification/test-plan.md) distinguishes these
infrastructure checks from the local authorization tests and records what would
need account-level evidence.
