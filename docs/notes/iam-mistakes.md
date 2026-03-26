# IAM Mistakes

Common IAM pitfalls encountered or studied during this project, and how they were avoided.

---

## Mistake 1: Wildcard Resource on S3 (`s3:*` or `Resource: "*"`)

**What goes wrong:** A Lambda role with `s3:GetObject` on `Resource: "*"` can read any object in any bucket in the account — including buckets belonging to unrelated services or stacks.

**How it was avoided:** The Lambda execution role policy scopes `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` to `arn:aws:s3:::<specific-bucket>/*` only. Nothing else.

**Lesson:** Always use the most specific ARN possible. If you can name the bucket, name it.

---

## Mistake 2: Lambda Reading `owner_id` from the Request Body

**What goes wrong:** If the Lambda function trusts a client-supplied `owner_id` field in the request JSON to determine file ownership, any user can forge another user's ID and access their files (IDOR).

**How it was avoided:** `owner_id` is read exclusively from `event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]` — injected by API Gateway after validating the Cognito JWT. Users cannot modify this value.

**Lesson:** Never trust client input for identity claims. Read identity from the verified token context, not the request payload.

---

## Mistake 3: Overly Permissive KMS Key Policy

**What goes wrong:** A KMS key policy that allows `kms:*` to `Principal: "*"` within the account means any IAM principal — including those spun up in future — can use the key. Combined with a misconfigured S3 policy, this could let unintended principals decrypt objects.

**How it was avoided:** The KMS key policy grants `kms:GenerateDataKey` and `kms:Decrypt` only to the Lambda execution role ARN and the Terraform deployment role. The key administrator is a separate role with no `kms:Decrypt`.

**Lesson:** Separate key administration (who can manage the key) from key usage (who can encrypt/decrypt with it).

---

## Mistake 4: Storing Secrets in Environment Variables Without Encryption

**What goes wrong:** Lambda environment variables are visible in plaintext in the AWS Console and in `terraform show` output if not encrypted. Anyone with `lambda:GetFunctionConfiguration` can read them.

**How it was avoided:** SecureDocs does not store secrets in environment variables. Resource ARNs (not credentials) are passed as env vars. Actual secrets (if needed) would use AWS Secrets Manager with a dedicated IAM `secretsmanager:GetSecretValue` permission.

**Lesson:** ARNs and region strings are config, not secrets. Real credentials belong in Secrets Manager or Parameter Store (SecureString), not `Environment` blocks.

---

## Mistake 5: No IAM Boundary for Developer Roles

**What goes wrong:** A developer role with `iam:CreateRole` and `iam:AttachRolePolicy` and no permission boundary can create a new role with `AdministratorAccess` and use it to escalate privileges — even if their own role has limited permissions.

**How it was avoided:** This is a known gap in the current dev setup (single-account, learning environment). Noted here so any production hardening step adds IAM permission boundaries to all user-created roles.

**Lesson:** `iam:CreateRole` without a permission boundary is effectively privilege escalation. In multi-team or production accounts, always enforce boundaries via SCPs (Service Control Policies) or permission boundary policies.
