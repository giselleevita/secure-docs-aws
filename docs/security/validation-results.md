# SecureDocs AWS Infrastructure Validation

This document is a sanitized validation example. It records the security checks that should be performed after deployment without publishing live account IDs, resource IDs, ARNs, endpoints, or client identifiers.

## Infrastructure Outputs

```json
{
  "api_endpoint_url": "https://<api_id>.execute-api.<region>.amazonaws.com",
  "bucket_name": "secure-docs-dev-<account_id>",
  "cognito_user_pool_id": "<region>_<user_pool_id>",
  "cognito_app_client_id": "<app_client_id>"
}
```

## Security Controls Validation

### 1. S3 Storage Layer

- **Encryption:** AWS KMS customer-managed key
- **Bucket Key:** Enabled for optimized encryption
- **Key ARN:** `arn:aws:kms:<region>:<account_id>:key/<key_id>`
- **Versioning:** Enabled on the SecureDocs bucket
- **Public Access:** All S3 block public access settings enabled

### 2. Authentication And Authorization

- **Cognito User Pool:** Deployed with email username attributes
- **App Client:** Created for API authentication flows
- **Authentication Flows:** Password and refresh-token flows configured for the learning environment
- **API Authorization:** API Gateway JWT authorizer validates Cognito-issued tokens

### 3. API Gateway

- **HTTP API:** SecureDocs API Gateway deployed
- **Endpoint:** Sanitized in public documentation
- **JWT Authorizer:** Cognito-integrated
- **Routes:**
  - `POST /upload-presigned` - JWT protected
  - `GET /list` - JWT protected
  - `GET /download/{id}` - JWT protected
  - `DELETE /delete/{id}` - JWT protected

### 4. Lambda Functions

- `lambda-upload-presigned` - generates S3 presigned PUT URLs
- `lambda-list-files` - queries user-owned file metadata from DynamoDB
- `lambda-download-file` - verifies ownership and generates presigned GET URLs
- `lambda-delete-file` - verifies ownership and deletes objects
- **Runtime:** Python 3.12
- **Environment Variables:** Resource names and ARNs only; no plaintext credentials

### 5. Database Layer

- **DynamoDB Table:** SecureDocs metadata table
- **Billing Mode:** PAY_PER_REQUEST
- **Primary Key:** `owner_id` partition key and `object_key` sort key
- **Ownership Boundary:** Lambda handlers use authenticated identity, not client-supplied owner IDs

### 6. Audit And Compliance Layer

#### CloudTrail

- **Trail Name:** SecureDocs CloudTrail
- **Logging:** Active with log file validation
- **Region Scope:** Single-region trail with global service events enabled in the current Terraform configuration
- **S3 Integration:** Logs delivered to a private CloudTrail log bucket
- **Coverage:** AWS API activity for the deployed environment

#### AWS Config

- **Recorder:** Configured for compliance tracking
- **Delivery Channel:** Configured for state-file storage

#### GuardDuty

- **Detector:** Configured for threat detection where supported
- **Note:** Service subscription and finding workflows must be verified in the deployed account

## Terraform State

```text
Apply Status: verified in a development environment
Last Validation: sanitized public example
Resource Identifiers: intentionally omitted from this public repository
```

## How To Query Outputs

```bash
terraform -chdir=infra/environments/dev output
terraform -chdir=infra/environments/dev output api_endpoint_url
terraform -chdir=infra/environments/dev output -json
```

Do not paste live output values into public documentation.

## Security Architecture Summary

**Defense in Depth:**

1. **Perimeter:** S3 bucket is private and has public access blocked.
2. **Identity:** JWT tokens are issued through Cognito.
3. **Data Protection:** S3 objects are encrypted with KMS.
4. **Application Logic:** Lambda verifies file ownership before S3 access.
5. **Audit Trail:** CloudTrail and CloudWatch Logs support investigation.
6. **Compliance:** AWS Config tracks infrastructure state.
7. **Threat Detection:** GuardDuty can detect anomalous account activity.

**Immutability And Recovery:**

- S3 versioning protects against accidental object deletion.
- CloudTrail log file validation supports tamper detection.
- DynamoDB point-in-time recovery should be enabled for production use.

## Next Steps For Production

1. [ ] Enforce MFA for administrative and sensitive user actions.
2. [ ] Add AWS Config managed rules for S3, IAM, KMS, and logging checks.
3. [ ] Configure CloudWatch alarms for suspicious API and storage patterns.
4. [ ] Enable GuardDuty findings notifications.
5. [ ] Test disaster recovery and state restore.
6. [ ] Implement DynamoDB point-in-time recovery.
7. [ ] Document incident response runbooks.
8. [ ] Review IAM policies with least-privilege tooling.
9. [ ] Add cross-account access only if required.
10. [ ] Configure DNS and certificate management for production.

---

**Region:** `<region>`
**Account ID:** `<account_id>`
