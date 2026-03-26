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
        logger.warning("action=delete_file status=rejected reason=missing_owner_id")
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    file_id = (event.get("pathParameters") or {}).get("id")
    if not file_id:
        logger.warning("action=delete_file owner_id=%s status=rejected reason=missing_file_id", owner_id)
        return {"statusCode": 400, "body": json.dumps({"error": "file_id required"})}

    logger.info("action=delete_file owner_id=%s file_id=%s status=checking_ownership", owner_id, file_id)

    table = dynamodb.Table(TABLE_NAME)
    result = table.get_item(Key={"owner_id": owner_id, "object_key": file_id})
    item = result.get("Item")

    if not item or item.get("owner_id") != owner_id:
        logger.warning("action=delete_file owner_id=%s file_id=%s status=forbidden", owner_id, file_id)
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    versions_response = s3.list_object_versions(Bucket=BUCKET_NAME, Prefix=file_id)
    delete_objects = [
        {"Key": v["Key"], "VersionId": v["VersionId"]}
        for v in versions_response.get("Versions", [])
    ] + [
        {"Key": m["Key"], "VersionId": m["VersionId"]}
        for m in versions_response.get("DeleteMarkers", [])
    ]

    if delete_objects:
        s3.delete_objects(Bucket=BUCKET_NAME, Delete={"Objects": delete_objects, "Quiet": True})

    logger.info("action=delete_file owner_id=%s file_id=%s status=s3_deleted", owner_id, file_id)

    table.delete_item(Key={"owner_id": owner_id, "object_key": file_id})

    logger.info("action=delete_file owner_id=%s file_id=%s status=ok", owner_id, file_id)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "deleted"}),
    }
