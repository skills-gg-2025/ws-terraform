import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    logger.info("Received Event: %s", json.dumps(event))

    try:
        detail = event.get("detail", {})
        instance_id = detail.get("requestParameters", {}).get("resourcesSet", {}).get("items", [{}])[0].get("resourceId")

        if not instance_id:
            logger.warning("Instance ID not found in event.")
            return {
                "statusCode": 400,
                "body": "Instance ID not found."
            }

        ec2.create_tags(
            Resources=[instance_id],
            Tags=[{"Key": "Environment", "Value": "production"}]
        )
        logger.info(f"태그 복원됨: {instance_id} → Environment=production")

        return {
            "statusCode": 200,
            "body": f"태그 복원 완료: {instance_id}"
        }

    except Exception as e:
        logger.error("오류 발생: %s", str(e))
        return {
            "statusCode": 500,
            "body": str(e)
        }
