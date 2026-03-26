# CloudTrail + CloudWatch Log Query: Correlate User Actions

## Problem

To investigate a security incident (e.g., "Did user X download file Y?"), you need to correlate:

- API Gateway access logs (request arrived, was authorized)
- CloudTrail S3 events (object was accessed)
- Lambda CloudWatch logs (owner_id, file_id, action)

## Solution: CloudWatch Logs Insights Query

### Query to Correlate All Three

```
fields @timestamp, @message, action, owner_id, file_id, status
| filter ispresent(action)
| stats by owner_id, file_id, action, status
```

### More Detailed Query with Timing

```
fields @timestamp, @message, @logStream, action, owner_id, file_id, status
| filter action IN ["upload", "list", "download", "delete"]
| stats count() as event_count, min(@timestamp) as first_event, max(@timestamp) as last_event by owner_id, action
| sort last_event desc
```

### Query to Find All S3 Access by a Specific User

```
fields @timestamp, eventName, requestParameters, userIdentity.principalId
| filter eventSource = "s3.amazonaws.com"
| filter requestParameters.bucketName = "secure-docs-dev-<account_id>"
| filter ispresent(requestParameters.key)
```

Then correlate with Lambda logs:

```
fields @timestamp, action, owner_id, file_id
| filter owner_id = "<user-sub-from-cognito>"
```

### Integration with CloudTrail Logs (if stored in CloudWatch)

If CloudTrail is configured to log to CloudWatch Logs (separate log group):

```
# CloudTrail log group query
fields eventTime, eventName, requestParameters.key, sourceIPAddress, userIdentity.principalId
| filter eventSource = "s3.amazonaws.com"
| filter requestParameters.bucketName = "secure-docs-dev-<account_id>"
| filter eventName IN ["GetObject", "PutObject", "DeleteObject"]
```

Then manually correlate with Lambda logs by:

1. Extract file_id from Lambda log
2. Search CloudTrail for same object key
3. Compare timestamps and source IP

## Running the Query

1. Go to CloudWatch → Logs → Log Insights
2. Select the Lambda log group (e.g., `/aws/lambda/lambda-download-file`)
3. Paste one of the queries above
4. Set time range (last 24 hours for daily review, last 7 days for incident investigation)
5. Run
6. Export results as CSV for documentation

## What to Look For

- **Normal flow:** owner_id appears in upload (create), list (read), download (read), delete (delete) with matching file_id
- **Anomaly:** owner_id_X trying to access file_id_Y that belongs to owner_id_Z → should see 403 in Lambda logs + no S3 event in CloudTrail
- **Unauthorized access:** S3 GetObject appears without corresponding Lambda download log → possible direct S3 access (should not happen if IAM roles are correct)

## Alerting

Create a CloudWatch Logs subscription filter to alert on:

```
[..., action = "delete", status = "ok"]
```

This detects file deletions and sends to SNS for audit purposes.
