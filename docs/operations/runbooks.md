# Operational Runbooks

Common procedures for operating, verifying, and recovering the SecureDocs AWS environment.

---

## Runbook 1: Verify a Clean Deployment

Run after every `terraform apply` to confirm all security controls are active.

```sh
# 1. Confirm S3 Block Public Access is enforced
aws s3api get-public-access-block --bucket <bucket-name>
# Expected: all four flags = true

# 2. Confirm KMS key rotation is enabled
aws kms get-key-rotation-status --key-id <key-id>
# Expected: KeyRotationEnabled = true

# 3. Confirm CloudTrail is logging
aws cloudtrail get-trail-status --name secure-docs-trail
# Expected: IsLogging = true

# 4. Run the secrets scan
sh scripts/security/check_secrets.sh
# Expected: no AKIA keys, private key material, or .env/.tfstate files
```

---

## Runbook 2: Investigate a 403 on File Download

A user reports they cannot download a file they believe they own.

1. Check the Lambda CloudWatch log group: `/aws/lambda/secure-docs-get-presigned-url`
2. Search for the `file_id` in question. Look for the log line: `owner_id mismatch` or `file not found in DynamoDB`.
3. If **owner mismatch**: the file was uploaded under a different Cognito `sub`. This is expected and correct behaviour — the 403 is not a bug.
4. If **file not found**: the DynamoDB item may have been deleted. Check DynamoDB point-in-time recovery or CloudTrail for a `DeleteItem` call on the table.
5. If **Lambda error**: check for IAM permission issues on the Lambda execution role (DynamoDB `GetItem`, KMS `GenerateDataKey`, S3 `GetObject`).

---

## Runbook 3: Rotate the KMS Key

KMS automatic rotation is enabled (annual). For a manual rotation or if a key is compromised:

1. Create a new KMS key in the same region.
2. Re-encrypt all S3 objects: `aws s3 cp s3://<bucket>/ s3://<bucket>/ --recursive --sse aws:kms --sse-kms-key-id <new-key-id> --metadata-directive REPLACE`
3. Update the Terraform variable `kms_key_id` and run `terraform apply`.
4. Schedule the old key for deletion (minimum 7-day waiting period): `aws kms schedule-key-deletion --key-id <old-key-id> --pending-window-in-days 7`
5. Verify no Lambda errors after the switch before proceeding with deletion.

---

## Runbook 4: Terraform Drift Check

Run before any planned change to confirm the live environment matches the committed config.

```sh
cd infra/environments/dev
terraform init
terraform plan -detailed-exitcode
# Exit code 0 = no drift. Exit code 2 = drift detected (review the plan).
```

If drift is detected: review the diff, identify whether it was a manual change or an external process, revert the manual change if unintended, then re-apply.
