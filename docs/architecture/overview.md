# System Overview

SecureDocs AWS is a serverless, single-tenant-per-user document store. Every
request is authenticated and every object access is authorized against the
caller's identity before any data is returned.

## Request flow

1. **Authenticate** — the client presents a Cognito-issued JWT. API Gateway's
   JWT authorizer validates it before any Lambda runs.
2. **Route** — API Gateway dispatches to one of four purpose-built Lambdas:
   `upload`, `list`, `download`, `delete`. Each has its own IAM role scoped to
   only the actions it needs.
3. **Authorize ownership** — the Lambda looks up file metadata in DynamoDB
   keyed by `owner_id` + `object_key`, and refuses (403) any access to an object
   the caller does not own.
4. **Access storage** — instead of proxying bytes or handing out S3 credentials,
   the Lambda returns a short-lived (5-minute) presigned URL. The bucket blocks
   public access, encrypts at rest with SSE-KMS, and keeps object versions.
5. **Audit** — API Gateway, Lambda, and S3 activity is captured by CloudTrail
   and CloudWatch Logs.

## Components

| Component | Role |
|---|---|
| Cognito | User identity and JWT issuance |
| API Gateway | JWT authorizer, routing |
| Lambda (×4) | Per-operation handlers, least-privilege IAM roles |
| DynamoDB | Ownership metadata (`owner_id`, `object_key`) |
| S3 | Encrypted, private, versioned object storage |
| KMS | Encryption keys for S3 objects |
| CloudTrail + CloudWatch | Audit trail |

See [decisions.md](./decisions.md) for the security rationale behind each choice.
