import json
import logging
import os

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]

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
        logger.warning("action=list_files status=rejected reason=missing_owner_id")
        return {"statusCode": 403, "body": json.dumps({"error": "forbidden"})}

    logger.info("action=list_files owner_id=%s status=querying", owner_id)

    table = dynamodb.Table(TABLE_NAME)
    response = table.query(
        KeyConditionExpression=Key("owner_id").eq(owner_id)
    )

    items = [
        {"file_id": item["object_key"], "file_name": item.get("file_name")}
        for item in response.get("Items", [])
    ]

    logger.info("action=list_files owner_id=%s status=ok count=%d", owner_id, len(items))

    return {
        "statusCode": 200,
        "body": json.dumps({"files": items}),
    }
