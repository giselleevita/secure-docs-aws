import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

BUCKET_NAME = os.environ["BUCKET_NAME"]
TABLE_NAME = os.environ["TABLE_NAME"]

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
        logger.warning("action=download_file status=rejected reason=missing_owner_id")
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    file_id = (event.get("pathParameters") or {}).get("id")
    if not file_id:
        logger.warning("action=download_file owner_id=%s status=rejected reason=missing_file_id", owner_id)
        return {"statusCode": 400, "body": json.dumps({"error": "file_id required"})}

    logger.info("action=download_file owner_id=%s file_id=%s status=checking_ownership", owner_id, file_id)

    table = dynamodb.Table(TABLE_NAME)
    result = table.get_item(Key={"owner_id": owner_id, "object_key": file_id})
    item = result.get("Item")

    if not item or item.get("owner_id") != owner_id:
        logger.warning("action=download_file owner_id=%s file_id=%s status=forbidden", owner_id, file_id)
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    presigned_url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET_NAME, "Key": file_id},
        ExpiresIn=300,
    )
    logger.info("action=download_file owner_id=%s file_id=%s status=presigned_generated", owner_id, file_id)

    return {
        "statusCode": 200,
        "body": json.dumps({"presigned_url": presigned_url}),
    }
