# SecureDocs AWS v1 Threat Model

## Overview

This document outlines the top security threats to SecureDocs AWS, how they would manifest, what controls are currently in place, and what remains to be addressed.

---

## Threat 1: Unauthorized Cross-User File Access via S3 API

### Description

User A gains access to User B's file by directly calling S3 GetObject, bypassing the Lambda authorization layer.

### How It Would Manifest

1. User A obtains the S3 object key (e.g., via CloudTrail, error message, or reverse DNS lookup)
2. User A calls `aws s3 get-object s3://secure-docs-dev-<acct>/uuid-goes-here file.pdf`
3. S3 returns the file to User A

### Current Controls

- **IAM role scoping:** Lambda roles have minimal S3 permissions (GetObject, PutObject, DeleteObject on the specific bucket)
- **S3 block public access:** Bucket has all four block settings enabled (prevents public URL access)
- **KMS encryption:** Objects are encrypted with customer-managed KMS key; User A cannot decrypt without the key
- **Lambda ownership check:** DynamoDB query validates owner_id before presigned URL generation (blocks direct S3 access)

### Remaining Gaps

- **No network isolation:** User A's EC2 instance (if in VPC) can reach S3 API if its IAM role has S3 permissions
  - **Fix:** Add S3 bucket policy to deny access except from specific Lambda IAM roles
  - **Fix:** Use VPC endpoints if running on EC2 / ECS
- **Presigned URL leakage:** If presigned URL is exposed (e.g., in logs, error messages, or email), User B can use it
  - **Fix:** Redact presigned URLs from logs; use short TTL (already done: 5 min)

### Detection

- CloudTrail: Unexpected S3 GetObject events from non-Lambda principals
- S3 access logs: GetObject requests with error codes (AccessDenied, SignatureDoesNotMatch)

---

## Threat 2: S3 Bucket Becomes Publicly Accessible (Misconfiguration)

### Description

S3 block public access settings are disabled, or a public bucket policy is added, exposing all files to the internet.

### How It Would Manifest

1. Attacker or misconfigured automation disables `block_public_acls` and `restrict_public_buckets`
2. Attacker adds a bucket policy allowing `s3:GetObject` from `*` (anonymous)
3. Attacker (or anyone) can download any file from the bucket via HTTP

### Current Controls

- **S3 block public access:** All four settings are enabled and managed by Terraform
- **AWS Config rule + Lambda remediation:** Automatically detects and corrects misconfiguration (see secure_docs_s3_public_access_remediation.md)
- **CloudTrail logging:** All S3 API calls are logged, including PutBucketPolicy
- **No public bucket policy:** Terraform does not set any bucket policy allowing public access

### Remaining Gaps

- **Terraform drift:** If someone manually disables block public access via Console, Terraform won't automatically re-apply (only Config rule + Lambda will)
  - **Fix:** Run `terraform plan` regularly; use Terraform Cloud / Enterprise for continuous compliance
- **Bucket policy drift:** If someone manually adds a public bucket policy, Config rule may not catch it (depends on rule configuration)
  - **Fix:** Expand Config rule to also check for overly permissive bucket policies

### Detection

- AWS Config dashboard: S3-bucket-public-read-prohibited rule
- CloudTrail: PutBucketPublicAccessBlock, PutBucketPolicy actions
- Lambda remediation logs: auto-remediation events

---

## Threat 3: Overprivileged IAM Role Leads to Bulk File Access

### Description

A Lambda role is granted broad S3 permissions (e.g., `s3:*` on all resources), allowing a compromised function to access or delete files outside its scope.

### How It Would Manifest

1. Attacker compromises a Lambda function (e.g., code injection, dependency vulnerability)
2. Attacker uses the Lambda's IAM role to enumerate and download files from User B's S3 path
3. Attacker modifies or deletes files in bulk

### Current Controls

- **Least-privilege IAM roles:** Each Lambda role is scoped to specific actions:
  - lambda-upload: s3:PutObject, s3:PutObjectVersion (only)
  - lambda-read: s3:GetObject, s3:GetObjectVersion (only)
  - lambda-delete: s3:DeleteObject, s3:DeleteObjectVersion (only)
- **Resource scoping:** S3 actions are limited to the specific bucket ARN + wildcard for objects
- **DynamoDB ownership check:** Lambda code validates owner_id before any S3 operation (defense-in-depth)
- **No s3:List\* permissions:** Roles cannot enumerate bucket contents

### Remaining Gaps

- **Wildcard object resource:** Current policy allows `arn:aws:s3:::bucket/*` (all objects)
  - **Fix (future):** If file_id format is standardized (e.g., user-prefixed), narrow to `arn:aws:s3:::bucket/user_a/*`
  - **Current mitigation:** DynamoDB ownership check prevents cross-user access even if S3 permissions are overly broad
- **No anti-exfiltration:** Attacker can still download all files matching the role's permissions if DynamoDB is bypassed
  - **Fix (future):** Add S3 Object Lock, SCP deny policies, or VPC endpoint logs to detect bulk access

### Detection

- CloudTrail: Unusual S3 API patterns (e.g., ListBucket, GetObject for non-owner files)
- Lambda logs: Ownership check failures (status=403)
- S3 access logs: Requests from Lambda role ARN for objects outside expected scope

---

## Threat 4: Stolen JWT Token Leads to Bulk Downloads

### Description

A user's Cognito ID token is leaked (e.g., via logs, email, or network capture), allowing an attacker to impersonate that user and download all their files.

### How It Would Manifest

1. Attacker obtains User A's JWT token (leak in email, captured in transit, etc.)
2. Attacker calls `curl -H "Authorization: Bearer <stolen_token>" https://api.../download/file_id`
3. API Gateway validates the token with Cognito; Lambda generates a presigned URL
4. Attacker downloads User A's files in bulk

### Current Controls

- **Short JWT lifetime:** Cognito ID tokens are short-lived (typically 1 hour)
- **HTTPS enforcement:** API Gateway enforces HTTPS (token not sent in plain HTTP)
- **Cognito token validation:** API Gateway authorizer validates signature and expiration
- **CloudTrail logging:** All S3 and API access is logged (attribution to Cognito sub, not user name)
- **Presigned URL TTL:** Presigned URLs expire after 5 minutes
- **Short presigned URL lifetime:** Even if token is stolen, presigned URLs are short-lived

### Remaining Gaps

- **No token revocation:** Cognito does not currently support per-token revocation (only user-level password reset)
  - **Fix (future):** Implement short TTL tokens (5-15 min) + refresh token rotation
  - **Fix (future):** Add approval required for sensitive operations (admin flag in Cognito + TOTP)
- **No rate limiting:** Attacker can download all files as fast as the API allows
  - **Fix (future):** Add API Gateway throttling / Lambda concurrency limits
  - **Fix (future):** Add CloudWatch alarm on unusual download patterns (e.g., downloading 1000 files in 1 minute)
- **No logout hook:** User cannot invalidate tokens if they suspect compromise
  - **Fix (future):** Implement manual logout (revoke refresh token) or admin invalidate

### Detection

- CloudTrail: Unusual login frequency or source IP for a user
- Lambda logs: Sudden spike in downloads from one owner_id
- API Gateway logs: High request rate from one source IP / Cognito sub
- CloudWatch alarm: Alert on > N downloads per hour for single user

---

## Threat 5: Poor Logging / Missing Audit Trail (Forensics Failure)

### Description

An incident occurs (file accessed, file deleted, unauthorized attempt), but there is insufficient logging to investigate root cause or attribute the action to a user.

### How It Would Manifest

1. SecureDocs admin suspects unauthorized file access
2. Admin checks CloudWatch logs, but they are sparse, truncated, or do not include owner_id
3. Admin cannot determine who accessed which file, when, or from where
4. Incident goes unresolved; compliance audit fails

### Current Controls

- **CloudTrail logging:** All S3, Lambda, and API Gateway API calls are logged to CloudTrail + CloudWatch Logs
- **Lambda structured logs:** Every Lambda function logs action, owner_id, file_id, status
- **DynamoDB Point-in-Time Recovery:** DynamoDB backups allow recovery of deleted items (with timestamps)
- **S3 versioning:** S3 object versions are retained; deletions are marked but not permanent
- **CloudWatch Logs retention:** Logs are retained for 365 days (configurable)

### Remaining Gaps

- **No centralized SIEM:** Logs are in separate systems (CloudTrail, CloudWatch, S3 access logs); investigation requires manual correlation
  - **Fix (future):** Ship logs to centralized logging (Splunk, Datadog, or ELK)
- **No real-time alerting:** No alerts on suspicious activity (e.g., delete spike, cross-user access attempts)
  - **Fix (future):** CloudWatch alarms + SNS for unusual patterns
- **No log immutability:** CloudWatch logs can be modified or deleted if IAM role is compromised
  - **Fix (future):** Ship logs to S3 with MFA Delete enabled; use S3 Object Lock

### Detection

- CloudWatch Logs Insights query: trace owner_id, file_id, action over time
- CloudTrail: search for DeleteObject, PutBucketPolicy, DeleteItem events
- DynamoDB restore: point-in-time recovery to check item state before deletion

---

## Threat 6: Overprivileged Administrator Account

### Description

A cloud administrator with excessive IAM permissions is compromised, granting attacker access to decrypt files, modify IAM roles, or delete audit logs.

### How It Would Manifest

1. Attacker compromises a developer's AWS credentials (phishing, malware, leaked keys)
2. Developer's IAM user has AdministratorAccess or custom policy with `kms:Decrypt`, `iam:PutRolePolicy`, `logs:DeleteLogGroup`
3. Attacker decrypts S3 files, modifies Lambda to exfiltrate data, deletes CloudTrail logs

### Current Controls

- **Least-privilege IAM roles for Lambda:** Each function has only required permissions (no admin access)
- **CloudTrail immutability:** CloudTrail logs are logged to S3 + CloudWatch (separate from user-modifiable logs)
- **KMS key policy:** KMS key is protected with explicit policy allowing only root + specific roles
- **No root access keys:** Root AWS account has no access keys (only IAM users)

### Remaining Gaps

- **No SCP (Service Control Policy):** Organization-level controls are not implemented
  - **Fix (future):** Add SCP denying iam:\* and kms:PutKeyPolicy for all non-admin users
- **No MFA enforcement:** Compromised IAM user credentials can be used without MFA check
  - **Fix (future):** Enforce MFA for all API calls (especially destructive ones like DeleteItem, PutBucketPolicy)
- **No session recording:** Impersonation or assume-role actions are not recorded in detail
  - **Fix (future):** CloudTrail should log AssumeRole events; add audit trail of who assumed which role

### Detection

- CloudTrail: Unusual iam:PutRolePolicy, kms:Decrypt, logs:DeleteLogGroup events
- CloudWatch: sudden increase in API calls from specific IAM user
- Access Analyzer: policies that allow excessive cross-account or public access

---

## Summary: What's Protected, What's Not

| Threat                | Protection Status                                       | Next Steps                                                 |
| --------------------- | ------------------------------------------------------- | ---------------------------------------------------------- |
| Cross-user S3 access  | **Protected:** DynamoDB ownership check + IAM scoping   | Add S3 bucket policy to deny non-Lambda principals         |
| S3 public access      | **Protected:** Block public access + Config remedy      | Add Config rule for bucket policy drift                    |
| Overprivileged Lambda | **Protected:** Least-privilege IAM + DynamoDB check     | Narrow S3 resource ARN when file_id format is standardized |
| Stolen JWT            | **Mitigated:** Short TTL presigned URLs + CloudTrail    | Implement token refresh rotation + rate limiting           |
| Poor audit trail      | **Protected:** CloudTrail + Lambda logs + S3 versioning | Centralize logs; add real-time alerting                    |
| Admin compromise      | **Partially:** KMS policy + CloudTrail immutability     | Add SCP + MFA enforcement + session recording              |

---

## Compliance & Standards Alignment

- **AWS Well-Architected Security Pillar:** logging, least-privilege, encryption ✓ (in progress for MFA, SCP)
- **CIS AWS Foundations:** S3 block public access, CloudTrail, encryption at rest ✓
- **GDPR:** Data encryption, audit trails, right to deletion (DynamoDB + S3 versioning) ✓
- **SOC 2:** Logging, access control, change tracking ✓ (audit trail is complete)
