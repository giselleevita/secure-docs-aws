# V3 Production-Ready Verification Plan

Verify that v3 production-ready features (VPC isolation, WAF, VPC endpoints, secrets management) are deployed and working correctly.

## Prerequisites

- SecureDocs v3 fully deployed (`terraform apply` completed in infra/environments/dev/)
- AWS CLI configured with dev profile credentials
- `curl`, `jq` installed

## V3 Verification Steps

### 1. Confirm WAF is attached to HTTP API Gateway

```bash
API_ID=$(terraform -chdir=infra/environments/dev output -raw api_endpoint_url | cut -d. -f1 | cut -d/ -f3)
aws apigatewayv2 get-apis --query "Items[?Name=='secure-docs-api'].Id" --output text
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn $(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='secure-docs-api-waf'].ARN" --output text) \
  --scope REGIONAL --query 'ResourceArns[*]'
```

**Expected:** WAF web ACL ARN returned; `api-gateway` resource appears in associated resources.

### 2. Confirm WAF rate-limiting is active

```bash
# Simulate rate limit breach (5000 requests in batches)
API_ENDPOINT=$(terraform -chdir=infra/environments/dev output -raw api_endpoint_url)
for i in {1..5000}; do 
  curl -s -o /dev/null -w "%{http_code}\n" "$API_ENDPOINT/list" -H "Authorization: Bearer dummy" &
  [ $((i % 100)) -eq 0 ] && wait
done
sleep 5

# Check sampled requests for 429 responses
aws wafv2 get-sampled-requests \
  --web-acl-arn $(aws wafv2 list-web-acls --scope REGIONAL --query "WebACLs[?Name=='secure-docs-api-waf'].ARN" --output text) \
  --rule-metric-name RateLimitRule \
  --scope REGIONAL \
  --time-window StartTime=$(( $(date +%s) - 600 )),EndTime=$(date +%s) \
  --max-items 20 --query 'SampledRequests[?ResponseCodeSent==`429`]'
```

**Expected:** Output shows multiple requests with `ResponseCodeSent: 429` after rate limit exceeded.

### 3. Confirm VPC Flow Logs are capturing endpoint traffic

```bash
aws logs get-log-events \
  --log-group-name /aws/vpc/secure-docs-flow-logs \
  --log-stream-name $(aws logs describe-log-streams --log-group-name /aws/vpc/secure-docs-flow-logs --order-by LastEventTime --descending --limit 1 --query 'logStreams[0].logStreamName' --output text) \
  --limit 10 --query 'events[].message' --output text | grep -E '443|53'
```

**Expected:** Recent flow log entries show traffic on port 443 (HTTPS to VPC endpoints) and 53 (DNS queries).

### 4. Confirm Lambda functions are in VPC and can reach all endpoints

```bash
# Invoke a Lambda function and check for VPC/endpoint connectivity
aws lambda invoke \
  --function-name lambda-upload-presigned \
  --payload '{}' \
  /tmp/lambda-test.json

# Check logs for successful endpoint access (no "endpoint unreachable" errors)
aws logs tail /aws/lambda/lambda-upload-presigned --max-items 5 --follow
```

**Expected:** Lambda executes without timeout; logs show successful S3/DynamoDB/KMS API calls; no "Network is unreachable" or "endpoint" errors.

### 5. Confirm Secrets Manager can be read via VPC endpoint (no internet)

```bash
# Create a test secret
aws secretsmanager create-secret \
  --name secure-docs/test-api-key \
  --secret-string '{"api_key":"test-value-12345"}' \
  --region eu-north-1

# Update Lambda IAM role to allow secret access (add inline policy)
UPLOAD_ROLE=$(terraform -chdir=infra/environments/dev output -json | grep -o '"upload_role_arn":"[^"]*"' | cut -d'"' -f4)
aws iam put-role-policy \
  --role-name $(basename "$UPLOAD_ROLE") \
  --policy-name lambda-secrets-access \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "secretsmanager:GetSecretValue",
        "Resource": "*"
      }
    ]
  }'

# Invoke Lambda with secret retrieval (check logs for no plaintext secret leakage)
aws logs tail /aws/lambda/lambda-upload-presigned --follow --max-items 5
```

**Expected:** Secret retrieved successfully via VPC endpoint; logs do **not** contain plaintext `api_key` value; function completes with status 200.

### 6. Confirm Lambda security group egress is restricted to VPC only

```bash
# Check Lambda security group rules
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=secure-docs-lambda-sg" \
  --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].IpPermissionsEgress[*].[FromPort,ToPort,IpProtocol,CidrIp]' --output table
```

**Expected:** Egress rules show only:
- Port 443 (HTTPS) to CIDR 10.0.0.0/16 (internal VPC)
- Port 53 (DNS) to CIDR 10.0.0.0/16 (internal VPC)
- No rules with 0.0.0.0/0 (internet) or ::/0

### 7. Confirm VPC endpoints exist and have private DNS enabled

```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform -chdir=infra/environments/dev output -json | grep -o '"vpc_id":"[^"]*"' | head -1 | cut -d'"' -f4)" \
  --query 'VpcEndpoints[*].[ServiceName,PrivateDnsEnabled,State]' --output table
```

**Expected:** Table shows 6 endpoints (S3, DynamoDB, KMS, Logs, STS, Secrets Manager) with `PrivateDnsEnabled: true` and `State: available`.

## Success Criteria

- ✅ All 7 steps complete without errors
- ✅ WAF attached and rate-limiting blocks at ~4000 requests
- ✅ VPC Flow Logs show endpoint traffic on ports 443/53 only
- ✅ Lambda executes inside VPC with no internet egress
- ✅ Secrets retrieved without plaintext leakage
- ✅ Security group restricts egress to VPC CIDR only
- ✅ All 6 VPC endpoints active with private DNS enabled
