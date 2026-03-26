# SecureDocs AWS – Project Overview & Security Story

## One-Line Summary

SecureDocs is a cloud-native document storage service where each user can upload, list, download, and delete their own files securely, with every operation authenticated, authorized, and audited—designed to teach and demonstrate cloud security principles on AWS.

---

## Architecture in Plain English

A user signs in with Cognito (AWS's managed identity service). Cognito issues a JWT token containing the user's unique identifier (sub claim). The user sends this token to the HTTP API Gateway, which validates the token against Cognito and extracts the user's identity into the Lambda event. The Lambda function uses this identity as the owner_id—a core security principle throughout the system.

When a user uploads a file, Lambda generates a random UUID as the file's object key (never a human-readable name), stores metadata in DynamoDB associating that UUID with the user's owner_id, and returns a short-lived presigned URL to the user. The user then uploads directly to S3 using that presigned URL. S3 encrypts the object with a KMS key, and the object is versioned.

When a user lists their files, Lambda queries DynamoDB for all items matching their owner_id and returns file metadata (file_id and file_name)—never exposing the owner_id to the client.

When a user downloads a file, they provide the file_id to Lambda, which checks DynamoDB to confirm they own it. If ownership is confirmed, Lambda generates a short-lived presigned URL. If not, Lambda returns a 403 Forbidden response.

When a user deletes a file, Lambda again confirms ownership before removing the item from DynamoDB and marking the S3 object as deleted.

CloudTrail logs all AWS API calls (S3, DynamoDB, KMS, Lambda invocations). CloudWatch Logs capture Lambda function output, where each handler logs the action, owner_id, file_id, and outcome. This creates an end-to-end audit trail.

---

## Security-Specific Features

### User Ownership Enforcement

Every read, write, and delete operation enforces ownership. The owner_id comes exclusively from the Cognito JWT token (the `sub` claim), never from user input. DynamoDB acts as the source of truth: before S3 operations occur, Lambda queries DynamoDB to confirm the user owns the file. This separation of concerns—combining authentication (Cognito), authorization (DynamoDB ownership check), and data access (S3)—prevents a single compromised component from exposing all files.

### Opaque Object Keys

S3 object keys are server-generated UUIDs. A user cannot choose or guess another user's file key. Even if an attacker gains S3 API access, they cannot enumerate the bucket or predict file names.

### S3 as a Private-by-Default Trust Boundary

The S3 bucket has all four block public access settings enabled, preventing accidental public exposure. Objects are encrypted at rest using a customer-managed KMS key (not the default S3-managed key), giving the application owner full control over who can decrypt. S3 versioning is enabled, creating an immutable audit trail; deleted objects leave delete markers rather than disappearing.

### Least-Privilege IAM Roles

Rather than one Lambda role with broad S3 permissions, there are three:

- Lambda-upload role can only PutObject and PutObjectVersion
- Lambda-read role can only GetObject and GetObjectVersion
- Lambda-delete role can only DeleteObject and DeleteObjectVersion

Each role is scoped to the specific S3 bucket and KMS key. If one Lambda function is compromised, the damage is limited to its designated operations.

### Presigned URLs, Never Direct S3 Access

Clients never make direct S3 API calls. They receive presigned URLs from Lambda, which are valid for 5 minutes. This ensures every access is logged in CloudWatch (via Lambda) and CloudTrail (via the presigned URL signature), and the token-holder cannot be tracked after expiration.

### Audit Trail: CloudTrail + CloudWatch Logs

CloudTrail captures all AWS API calls, including S3 GetObject, PutObject, and DeleteObject. CloudWatch Logs capture structured Lambda output (action, owner_id, file_id, status). Together, they form a complete timeline: who (owner_id), did what (action), on which file (file_id), when, and with what outcome. This enables forensic investigation and compliance reporting.

---

## Threat Model: How Risks Were Addressed

### Threat 1: One User Sees Another's File

**The Risk:** If user A obtains user B's file ID (a UUID), could they download it?

**The Mitigation:** Lambda validates ownership in DynamoDB before generating a presigned URL. Even if user A knew user B's file ID, they would receive a 403 Forbidden response. The ownership check is a hard gate; no workaround exists at the Lambda or API Gateway layer.

**Why It Works:** Security is enforced at the authorization layer (Lambda), not just at the transport layer (TLS). The S3 bucket policy is not restrictive (it allows the Lambda role to access any object), but the application logic ensures only owners can request presigned URLs.

**What Remains:** If a presigned URL is leaked (e.g., shared in an insecure channel), anyone with the URL can use it until expiration (5 minutes). Mitigation: short TTL and user responsibility to not share URLs. A rate-limiting layer (not yet implemented) would slow brute-force URL guessing.

### Threat 2: S3 Bucket Becomes Public

**The Risk:** An admin disables block public access or adds a public bucket policy, exposing all files to the internet.

**The Mitigation:** AWS Config detects when block public access settings are disabled and triggers a Lambda remediation that automatically re-enables them. CloudTrail logs all changes to bucket policy and access settings. If misconfiguration occurs, it is detected and corrected within minutes.

**Why It Works:** Defense-in-depth. The baseline is secure (block public access enabled, no public policy). An automated detector and corrector exists. Humans are not the only line of defense.

**What Remains:** If an admin disables both the remediation Lambda and the Config rule, the bucket could be exposed and stay exposed. This is a "keys to the kingdom" scenario that requires exceptional IAM privileges and would be visible in CloudTrail. Mitigation: restrict who can disable Config rules and Lambda functions (SCPs, MFA).

### Threat 3: IAM Role Is Overprivileged

**The Risk:** A Lambda role is granted `s3:*` on all resources. A compromised function could access files outside its scope.

**The Mitigation:** Lambda roles are granular: upload role has only PutObject, read role has only GetObject, etc. Additionally, the application layer enforces ownership; even if a role could technically access any S3 object, Lambda will not generate a presigned URL for an object the user does not own.

**Why It Works:** Least-privilege + defense-in-depth. Even if one control fails (IAM is too broad), the next control (application ownership check) prevents damage. The DynamoDB query is the gate-keeper.

**What Remains:** In a true "keys to the kingdom" scenario (attacker compromises the AWS account root or calls S3 APIs directly), IAM cannot be the only defense. Mitigation: object-level encryption with customer-managed keys ensures data is unreadable without explicit KMS permissions (which are also least-privilege).

### Threat 4: JWT Token Is Stolen

**The Risk:** An attacker obtains a user's Cognito ID token (leaked in logs, email, or network sniffer) and uses it to impersonate the user.

**The Mitigation:** ID tokens from Cognito are short-lived (1 hour by default). Even if stolen, the attacker can use it only until expiration. Additionally, presigned URLs are valid for only 5 minutes, so even if a token is used to request many presigned URLs, they are not reusable after 5 minutes. CloudTrail logs every S3 access, so bulk downloads by one user would be visible in reviews.

**Why It Works:** Time is a control. Tokens expire. URLs expire. A stolen token does not grant permanent access.

**What Remains:** The attacker can download files as long as the token is valid (up to 1 hour) or the presigned URL is valid (up to 5 minutes). Mitigation: shorter token lifetimes, token refresh rotation, and real-time alerting on unusual access patterns (e.g., one user downloading 1000 files in 1 minute).

### Threat 5: Poor Logging / No Audit Trail

**The Risk:** After an incident, the team cannot determine who accessed which files, when, or how.

**The Mitigation:** CloudTrail logs every S3, DynamoDB, and Lambda API call. CloudWatch Logs capture structured output from every Lambda handler. DynamoDB point-in-time recovery preserves the state of the table at any moment. S3 versioning preserves all object versions and delete markers.

**Why It Works:** Multiple systems log independently, so if one is compromised or deleted, others remain. Logs are stored in CloudTrail (immutable to some extent) and CloudWatch (retained for 365 days by default).

**What Remains:** Logs are not centralized (they live in three separate AWS services: CloudTrail, CloudWatch, S3). Manual correlation is required to tie together "user uploaded file via API Gateway" + "Lambda invoked" + "S3 PutObject occurred". Mitigation: ship logs to a centralized SIEM (Splunk, Datadog) for automated correlation and alerting.

---

## What Was Built vs. What Was Learned

### Built: A Complete Cloud Application

I deployed a production-ready serverless architecture with Cognito identity, HTTP API Gateway with JWT authorization, four Lambda functions with role-based permissions, DynamoDB for metadata, S3 for storage with KMS encryption, and comprehensive logging via CloudTrail and CloudWatch. The infrastructure is defined entirely as Terraform code, allowing version control, reproducibility, and automated testing.

### Learned: How Ownership Is Enforced, Not Just Implemented

Building this project shifted my understanding from "permissions are defined in IAM" to "permissions are enforced by the application, with IAM as a supporting layer." The ownership check in DynamoDB is not a feature—it is a security principle. If that check is removed, the whole system fails, regardless of IAM configuration.

### Learned: S3 Is a Trust Boundary, Not a Security Tool

S3 is designed for durability and scalability, not for access control. The security comes from:

- Who can request presigned URLs (Lambda, validated by Cognito)
- What metadata validates that request (DynamoDB ownership check)
- How objects are encrypted (KMS with separate key policy)
- How access is audited (CloudTrail + presigned URL signatures)

S3 itself does not know about users or ownership. The application layer creates that abstraction.

### Learned: IAM Is a Prerequisite, Not a Guarantee

Least-privilege IAM (upload role can only PUT, read role can only GET) is necessary but not sufficient. The application still enforces ownership. This layering ensures that even a misconfigured IAM role or insider threat is checked by the application logic.

### Learned: Audit Trails Are Not Optional

CloudTrail and CloudWatch Logs transformed the project from "something that works" to "something that is trustworthy." Without these, there is no way to investigate incidents, prove compliance, or detect fraud. Logging is security infrastructure.

---

## Interview-Ready Summary

**What This Project Is:**

SecureDocs is a multi-user document storage service where Cognito authenticates users, API Gateway authorizes requests with JWT tokens, Lambda functions execute business logic, DynamoDB stores metadata, and S3 stores encrypted files. Every operation is owned (tied to a user), audited (logged in CloudTrail and CloudWatch), and enforced at the application layer.

**What Security Lessons It Teaches:**

1. **Ownership is a design principle, not a feature.** Every read, write, and delete must validate that the user owns the resource. This is checked in DynamoDB before S3 operations occur.

2. **Defense-in-depth is practical.** No single layer (IAM, encryption, logging, application code) is sufficient. Layered controls catch failures in other layers.

3. **Trust boundaries are not where you think.** S3 is not a security tool; it is a storage tool. The security comes from Cognito (identity), DynamoDB (ownership), KMS (encryption), and Lambda (access control).

4. **Least-privilege is granular, not just organizational.** Upload, read, and delete operations have separate IAM roles with different permissions. A compromised upload function cannot read or delete files.

5. **Audit trails are a requirement, not a checkbox.** CloudTrail and CloudWatch Logs are part of the architecture, not an afterthought. They enable investigation, compliance, and detection of anomalies.

**Why This Makes You a Cloud Security Developer:**

- I did not just build a feature; I modeled a threat and designed controls. For each threat (stolen token, overprivileged role, public bucket), I identified a mitigation and understood its limitations.
- I understand that cloud security is not a product; it is a system. Identity, access, encryption, logging, and compliance are interlocking parts.
- I can explain to a non-technical stakeholder why presigned URLs are better than public S3 links, why DynamoDB ownership checks matter, and why audit logs are non-negotiable.
- I can write Terraform that enforces security by default (block public access, encryption, versioning) and Lambda that checks authorization at the application layer.
- I have faced the constraint of "no database is perfectly consistent, no network is perfectly reliable, no token is perfectly safe" and designed for those realities.

This is not a "Hello World" cloud project. It is a project where every decision has a security reason, and I can explain each one.
