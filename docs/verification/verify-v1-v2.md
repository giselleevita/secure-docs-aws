# V1/V2 Core Functionality Verification

Tests for the original SecureDocs functionality: user authentication, file operations, ownership enforcement, and audit logging.

## Prerequisites

- AWS account with SecureDocs deployed (`terraform apply` completed)
- AWS CLI configured with credentials
- `curl`, `jq` installed

## Steps

### 1. Export environment variables

From the `infra/environments/dev/` directory:

```bash
export AWS_REGION=eu-north-1
export USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export APP_CLIENT_ID=$(terraform output -raw cognito_app_client_id)
export API_ENDPOINT_URL=$(terraform output -raw api_endpoint_url)
```

### 2. Run the core functionality script

```bash
bash verify_secure_docs.sh
```

## Expected Output

- Script exits with **0** on success
- All legitimate API calls return **2xx** responses
- Cross-user access attempts return **403 Forbidden**
- Each step prints `✅ step_name` on success or `❌ error` on failure

## What It Tests

1. **User creation** — Creates two test users in Cognito
2. **Authentication** — Obtains JWT tokens via admin-initiate-auth
3. **Upload** — User A uploads a file and gets a presigned PUT URL
4. **List** — User A sees their own file; User B does not see it
5. **Download** — User A downloads their file via presigned GET URL
6. **Cross-user denial** — User B cannot download or delete User A's file (403)
7. **Delete** — User A deletes their file and list becomes empty

The script cleans up test users but leaves the stack deployed for manual inspection.

## Verifying Audit Layer (CloudTrail + Config + GuardDuty)

After running the core tests:

1. **CloudTrail Logs** — In AWS Console, navigate to CloudTrail > Event history. Filter by `S3 PutObject` events and confirm the upload is logged with timestamp, user, and resource.

2. **CloudWatch Logs** — In CloudWatch > Log groups, check `/aws/lambda/` for structured output. Confirm log entries show `owner_id`, `file_id`, `action`, and `status`.

3. **Config Compliance** — In AWS Config > Rules, confirm recorder is active and rules are evaluating S3 bucket configuration (encryption, block public access).

4. **GuardDuty Findings** — In GuardDuty > Findings, confirm detector is active and has scanned S3/API calls. No critical findings expected.

5. **Cross-User Audit** — Upload as user A, attempt download as user B. Confirm API returns 403. Check CloudWatch logs for ownership denial event.
