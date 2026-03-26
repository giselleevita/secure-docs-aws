import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))
    logger.info("Context: %s", str(context))

    if "requestContext" in event:
        claims = (
            event.get("requestContext", {})
            .get("authorizer", {})
            .get("jwt", {})
            .get("claims", {})
        )
        owner_id = claims.get("sub", "unknown")
        logger.info("owner_id: %s", owner_id)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "placeholder handler"}),
    }
