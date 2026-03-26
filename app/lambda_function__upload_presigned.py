import json
import logging
import os
import uuid

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

BUCKET_NAME = os.environ["BUCKET_NAME"]
TABLE_NAME = os.environ["TABLE_NAME"]
KMS_KEY_ARN = os.environ["KMS_KEY_ARN"]

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")


def handler(event, context):
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    owner_id = claims.get("sub")
    if not owner_id:
        logger.warning("action=upload_presigned status=rejected reason=missing_owner_id")
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    body = json.loads(event.get("body") or "{}")
    file_name = body.get("file_name")
    if not file_name:
        logger.warning("action=upload_presigned owner_id=%s status=rejected reason=missing_file_name", owner_id)
        return {"statusCode": 400, "body": json.dumps({"error": "file_name required"})}

    object_key = str(uuid.uuid4())

    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            "owner_id": owner_id,
            "object_key": object_key,
            "file_name": file_name,
        }
    )
    logger.info("action=upload_presigned owner_id=%s file_id=%s file_name=%s status=ddb_written", owner_id, object_key, file_name)

    presigned_url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": BUCKET_NAME,
            "Key": object_key,
            "ServerSideEncryption": "aws:kms",
            "SSEKMSKeyId": KMS_KEY_ARN,
        },
        ExpiresIn=300,
    )
    logger.info("action=upload_presigned owner_id=%s file_id=%s status=presigned_generated", owner_id, object_key)

    return {
        "statusCode": 200,
        "body": json.dumps({"presigned_url": presigned_url, "file_id": object_key}),
    }
