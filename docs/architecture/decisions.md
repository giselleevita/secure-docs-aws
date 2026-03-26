# Architecture Decisions

Key design choices made during the SecureDocs AWS build, with the reasoning behind each.

---

## ADR-001: Private S3 Bucket + KMS Customer-Managed Key

**Chosen:** All objects stored in a private S3 bucket with server-side encryption using a customer-managed KMS key (SSE-KMS). Bucket versioning enabled. All four S3 Block Public Access settings are on.

**Why:** Defense-in-depth — if an IAM policy drifts or is misconfigured, objects are still not publicly accessible and cannot be read without the KMS key. Versioning provides an accidental-deletion recovery path.

**Trade-off:** Slightly higher latency and cost per request (KMS API call on every object). Accepted because this is a security-first learning project.

---

## ADR-002: Lambda as Authorization Middleware (No Direct S3 Access)

**Chosen:** Users never receive long-lived S3 credentials. Every file operation goes through a Lambda function, which validates ownership against DynamoDB before issuing a short-lived presigned URL.

**Why:** Keeps the authorization logic in one place. S3 presigned URLs are scoped to a single object and expire (default 15 minutes), so a leaked URL has a small blast radius.

**Trade-off:** Lambda becomes a chokepoint; horizontal scaling must be verified under load. Accepted for simplicity at portfolio scale.

---

## ADR-003: Cognito JWT `sub` Claim as Owner Identifier

**Chosen:** The `owner_id` stored in DynamoDB is the Cognito `sub` claim extracted from the validated JWT by API Gateway — never from a user-supplied request body or query parameter.

**Why:** Prevents client-side IDOR (Insecure Direct Object Reference). A user cannot forge their identity by changing a field in the request.

**Trade-off:** Tightly couples the ownership model to Cognito. Replacing the identity provider in future would require a data migration of `owner_id` values.

---

## ADR-004: UUID Object Keys (Not File Names)

**Chosen:** S3 object keys are randomly generated UUIDs. Human-readable file names are stored only in DynamoDB metadata.

**Why:** Prevents object-key enumeration attacks. Even if an adversary can list bucket contents (which is blocked by IAM, but assumed as a failure mode), they cannot infer which object belongs to which user.

**Trade-off:** Debugging and manual inspection are harder because S3 keys are opaque. Accepted — the DynamoDB `file_id`→`file_name` mapping is the lookup layer for operators.
