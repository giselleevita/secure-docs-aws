# AWS Concepts

Glossary-style notes on the AWS services used in SecureDocs. Written to reinforce understanding during the build, not as a replacement for official docs.

---

## Cognito

AWS's managed user identity service. In SecureDocs, Cognito acts as the authentication layer — it handles sign-up, sign-in, and JWT issuance. API Gateway validates the JWT on every request and extracts the `sub` claim (a stable, unique user identifier) into the Lambda event context.

**Key mental model:** Cognito issues the identity; Lambda enforces the authorization. They are separate responsibilities.

---

## API Gateway (HTTP API)

Sits in front of Lambda. Handles TLS termination, request routing, throttling, and — when a Cognito authorizer is attached — JWT validation. The HTTP API variant is lighter and cheaper than REST API; it supports Cognito JWT authorizers out of the box.

**Key mental model:** API Gateway is not just a reverse proxy. With an authorizer attached, it rejects unauthenticated requests _before_ Lambda is even invoked, reducing both cost and attack surface.

---

## S3

Object storage. In SecureDocs: private bucket, SSE-KMS encryption, versioning on, all Block Public Access settings enabled. Objects are accessed exclusively via Lambda-generated presigned URLs (time-limited, scoped to one object, one HTTP method).

**Key mental model:** A presigned URL is a short-lived capability token. It delegates one specific S3 action (GET or PUT) to whoever holds it, without granting the caller any IAM permissions directly.

---

## DynamoDB

NoSQL key-value / document store. In SecureDocs, DynamoDB is the ownership registry — it maps `file_id` (UUID) to `owner_id` (Cognito `sub`) and `file_name`. Lambda queries this before every S3 operation.

**Key mental model:** DynamoDB is the authorization oracle, not S3. S3 does not know who owns which object; that judgement lives in DynamoDB + Lambda logic.

---

## KMS (Key Management Service)

Manages cryptographic keys. A customer-managed key (CMK) is used for S3 SSE-KMS. Automatic annual rotation is enabled. KMS keeps all prior key versions active for decryption, so old objects remain readable after rotation.

**Key mental model:** Enabling rotation does not break existing data. KMS tracks which key version encrypted each object and decrypts accordingly.

---

## CloudTrail

Records every AWS API call (who called what, when, from where). In SecureDocs, CloudTrail provides the audit trail for S3 object access, DynamoDB queries, KMS key usage, and Lambda invocations. Logs are delivered to an S3 bucket.

**Key mental model:** CloudTrail is detective, not preventive. It tells you what happened; IAM and bucket policies prevent it from happening in the first place.

---

## IAM (Identity and Access Management)

The permissions system for all AWS actions. In SecureDocs, the Lambda execution role has least-privilege permissions: only the specific S3 bucket actions it needs, only the specific DynamoDB table, only the specific KMS key. No wildcards on sensitive resources.

**Key mental model:** IAM controls what AWS principals _can_ do. Every permission not explicitly granted is denied by default.
