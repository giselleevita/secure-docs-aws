# SecureDocs AWS Test Plan

## Test Case 1: Normal User Flow (Happy Path)

**Objective:** Verify all operations work correctly for a single user.

**Input:**

- User A authenticates to Cognito
- User A calls POST /upload-presigned with file_name="test.pdf"
- User A calls GET /list
- User A calls GET /download/{file_id}
- User A calls DELETE /delete/{file_id}

**Expected Behavior:**

- Upload returns 200 with presigned_url + file_id
- List returns 200 with exactly 1 file (file_id, file_name visible; owner_id hidden)
- Download returns 200 with presigned_url (valid for 5 minutes)
- Delete returns 200; subsequent list shows 0 files

**Where to Look:**

- Lambda CloudWatch logs: `action=upload status=..`, `action=delete status=ok`
- DynamoDB (on-demand) should show 1 item after upload, 0 after delete
- S3 (versioned): 1 object version after upload, delete markers after delete

---

## Test Case 2: Cross-User Access Attempt (Ownership Enforcement)

**Objective:** Verify users cannot access each other's files.

**Input:**

- User A uploads file (file_id_A)
- User B uploads file (file_id_B)
- User B calls GET /download/{file_id_A}
- User B calls DELETE /delete/{file_id_A}

**Expected Behavior:**

- User B's download attempt returns 403 Forbidden (with message "error": "forbidden")
- User B's delete attempt returns 403 Forbidden
- User A's file remains intact (list still shows 1 file, S3 object still exists)

**Where to Look:**

- Lambda CloudWatch logs for download/delete should show: `owner_id=<user_b_sub> file_id=<file_id_a> status=forbidden` or `status=rejected`
- No S3 GetObject or DeleteObject events in CloudTrail for file_id_A under user B's principal
- DynamoDB: no DeleteItem for file_id_A with owner_id != user_b

---

## Test Case 3: Spoofed owner_id in Request (Input Validation)

**Objective:** Verify Lambda ignores client-provided owner_id; uses only JWT sub claim.

**Input:**

- User A calls POST /upload-presigned with:
  ```json
  {
    "file_name": "exploit.pdf",
    "owner_id": "<user_b_sub>"
  }
  ```

**Expected Behavior:**

- Upload succeeds (HTTP 200)
- DynamoDB item is created with owner_id=<user_a_sub> (not user_b_sub)
- When user B lists files, the uploaded file does NOT appear
- When user A lists files, it DOES appear

**Where to Look:**

- Lambda code: verify `owner_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]` (never from request body)
- DynamoDB: the item's owner_id attribute should match user A's sub, not the spoofed value
- Test frameworks: use test_secure_docs.sh as baseline

---

## Test Case 4: S3 Block Public Access Misconfiguration & Auto-Remediation

**Objective:** Verify Config rule + Lambda remediation restores security posture automatically.

**Input:**

1. Manually disable S3 block public access (via AWS Console or CLI):
   ```bash
   aws s3api put-bucket-public-access-block \
     --bucket secure-docs-dev-<account_id> \
     --public-access-block-configuration \
       BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
   ```
2. Wait 1 minute for AWS Config to detect

**Expected Behavior:**

- AWS Config rule fires
- Lambda remediation function invokes
- S3 bucket block public access settings are re-enabled (all four return to true)
- CloudWatch log shows "Successfully re-enabled block public access for..."
- SNS alert is published (check email or SQS subscription)

**Where to Look:**

- AWS Config dashboard: rule should show "Non-compliant" briefly, then "Compliant"
- Lambda CloudWatch logs: check remediation function's log group
- SNS (if subscribed): alert message
- S3 Console: verify BlockPublicAcls, etc. are all checked/true

---

## Test Case 5: Cognito Authorizer Removed (Negative Test)

**Objective:** Verify API Gateway rejects unauthenticated requests.

**Input:**

1. Temporarily remove Cognito authorizer from GET /list route (via Terraform or Console)
2. Call GET /list without Authorization header
3. Call GET /list with an invalid or expired token

**Expected Behavior:**

- Without header: API Gateway returns 401 Unauthorized (or 403 depending on default)
- With invalid token: API Gateway returns 401
- Lambda is never invoked

**Where to Look:**

- API Gateway access logs: should show 401/403 response
- Lambda CloudWatch logs: no entries (function was not called)
- Curl output: check response headers and status code

---

## Test Case 6: Lambda Timeout / Permission Denied (Failure Modes)

**Objective:** Verify graceful error handling when IAM permissions or services fail.

**Input:**

1. Manually remove `dynamodb:GetItem` permission from lambda-read IAM role
2. Call GET /download/{file_id}

**Expected Behavior:**

- Lambda function executes but fails on DynamoDB query
- CloudWatch logs show error (access denied, etc.)
- API Gateway returns 500 (or Lambda error response)
- No partial data is leaked

**Where to Look:**

- Lambda CloudWatch logs: error traceback showing permission denied
- API Gateway access logs: 500 Internal Server Error
- DynamoDB access patterns: no successful queries for that role/action

---

## Test Case 7: Presigned URL Expiration

**Objective:** Verify presigned URLs expire and prevent access after TTL.

**Input:**

1. User A, uploads file, gets presigned_url (5-minute TTL)
2. Wait 6 minutes
3. Try to use presigned_url to PUT / GET

**Expected Behavior:**

- S3 returns 400 / 403 (request signature expired)
- File is not uploaded or downloaded

**Where to Look:**

- S3 access logs: ExpiredToken or SignatureDoesNotMatch in error codes
- HTTPStatusCode: >= 400 (not 2xx)

---

## Test Case 8: Concurrent Uploads / List Consistency

**Objective:** Verify DynamoDB consistency with concurrent operations.

**Input:**

1. User A calls POST /upload-presigned (gets file_id_1)
2. While that request is in-flight, user A calls GET /list
3. Repeat: another upload (file_id_2) happens concurrently

**Expected Behavior:**

- List may or may not include file_id_1 (depends on DynamoDB consistency; with on-demand billing, eventually consistent)
- After a few seconds, both file_id_1 and file_id_2 appear in list
- No errors or duplicates

**Where to Look:**

- Lambda CloudWatch logs: timestamps of upload + list requests
- DynamoDB: item count eventually reaches expected value
- (DynamoDB on-demand is eventually consistent; this is acceptable for SecureDocs v1)

---

## Running All Tests

```bash
cd /path/to/secure-docs-aws
bash test_secure_docs.sh
```

This script automates Test Cases 1, 2, and implicit validation of Test Case 3 (spoofed owner_id).

For Test Cases 4–8, use manual AWS CLI / Console steps as outlined above.

---

## Success Criteria

- [ ] Test 1: All operations return expected status codes
- [ ] Test 2: Cross-user access returns 403
- [ ] Test 3: Spoofed owner_id is ignored; file is assigned to caller's account
- [ ] Test 4: Config rule detects misconfiguration; Lambda remediates within 2 minutes
- [ ] Test 5: Unauthenticated requests are rejected before Lambda is invoked
- [ ] Test 6: Missing IAM permissions are logged; error is not exposed to client
- [ ] Test 7: Presigned URLs expire as expected
- [ ] Test 8: Concurrent operations do not corrupt state (eventually consistent)
