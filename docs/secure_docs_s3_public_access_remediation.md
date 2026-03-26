# AWS Config Rule + Lambda Remediation: S3 Public Access Block

## Problem

S3 bucket block public access settings are critical defaults to prevent accidental public exposure. Misconfiguration (disabling block public access) is a common attack vector.

## Solution Pattern

### Config Rule Detection

Create an AWS Config rule that detects when `s3:BlockPublicAcls`, `s3:BlockPublicPolicy`, `s3:IgnorePublicAcls`, or `s3:RestrictPublicBuckets` is set to `false`.

**Rule Type:** Custom Lambda (or use `s3-bucket-public-read-prohibited` if available)

**Trigger:** Parameter change (Config detects when block public access settings change)

### Lambda Remediation

When Config detects a violation, invoke a Lambda function to:

1. Check the bucket name and account ID
2. Re-enable all four block public access settings
3. Log the remediation action to CloudWatch
4. Publish an SNS alert to security team

**Handler pseudocode:**

```python
import boto3
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
sns = boto3.client("sns")

def remediate(event, context):
    config_item = json.loads(event["configurationItem"])
    bucket_name = config_item["resourceName"]

    logger.info("Remediating S3 bucket: %s", bucket_name)

    s3.put_bucket_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        }
    )

    logger.info("Successfully re-enabled block public access for %s", bucket_name)

    sns.publish(
        TopicArn="arn:aws:sns:eu-north-1:<account>:security-alerts",
        Message=f"Bucket {bucket_name} had public access settings disabled. Auto-remediation applied.",
        Subject="S3 Bucket Public Access Remediation"
    )

    return {"statusCode": 200, "message": "Remediated"}
```

### Deployment Steps

1. Create Lambda role with `s3:PutBucketPublicAccessBlock` and `sns:Publish` permissions
2. Deploy Lambda function (above code)
3. Create AWS Config rule pointing to Lambda
4. Set Config rule to auto-remediate on violation
5. Test: manually disable block public access in console
6. Verify Lambda remediation re-enables it within seconds
7. Check CloudWatch logs for "Successfully re-enabled..." message

## Why This Matters

- **First line of defense:** Block public access prevents 80% of S3 exposure incidents
- **Automated:** Reduces MTTR from manual investigation to seconds
- **Auditable:** CloudWatch logs + SNS alerts provide full trail
- **Compliant:** Meets CIS, AWS Well-Architected, and many regulatory frameworks
