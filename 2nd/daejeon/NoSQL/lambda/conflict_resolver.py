import json
import boto3
from datetime import datetime, timezone

dynamodb = boto3.client('dynamodb', region_name='ap-northeast-2')
TABLE_NAME = "account-table"

def lambda_handler(event, context):
    try:
        for record in event.get('Records', []):
            if record['eventName'] in ['MODIFY', 'INSERT']:
                account_id = record['dynamodb']['Keys']['account_id']['S']
                resolve_conflict(account_id)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Conflict resolution completed')
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def resolve_conflict(account_id):
    try:
        response = dynamodb.get_item(
            TableName=TABLE_NAME,
            Key={'account_id': {'S': account_id}}
        )
        
        if 'Item' not in response:
            return
        
        now = datetime.now(timezone.utc).isoformat()
        
        dynamodb.update_item(
            TableName=TABLE_NAME,
            Key={'account_id': {'S': account_id}},
            UpdateExpression='SET last_updated = :ts',
            ExpressionAttributeValues={
                ':ts': {'S': now}
            }
        )
        
        print(f"Conflict resolved for account: {account_id}")
        
    except Exception as e:
        print(f"Error resolving conflict: {str(e)}")
        raise e