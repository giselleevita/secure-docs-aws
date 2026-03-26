# How to Run the End-to-End Verification

The `verify_secure_docs.sh` script tests that the SecureDocs AWS stack works end-to-end: user authentication, file upload with presigned URLs, ownership enforcement, and cross-user access denial.

## Prerequisites

- AWS account with SecureDocs AWS deployed (`terraform apply` completed)
- awscli configured with credentials
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

### 2. Run the verification script

```bash
bash /path/to/verify_secure_docs.sh
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
