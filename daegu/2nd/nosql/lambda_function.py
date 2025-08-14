import json
import boto3
from datetime import datetime
from decimal import Decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('chat-messages')

class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

def lambda_handler(event, context):
    try:
        http_method = event['httpMethod']
        path = event['resource']
        
        if path == '/send-messages' and http_method == 'POST':
            return send_message(event)
        elif path == '/get-messages' and http_method == 'GET':
            return get_messages(event)
        elif path == '/update-messages' and http_method == 'PUT':
            return update_message(event)
        elif path == '/delete-messages' and http_method == 'DELETE':
            return delete_message(event)
        else:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Not found'})
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def send_message(event):
    body = json.loads(event['body'])
    room_id = body.get('RoomID')
    message = body.get('Message')
    
    if not room_id or not message:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing parameters'})
        }
    
    timestamp = datetime.utcnow().isoformat()
    
    table.put_item(Item={
        'RoomID': room_id,
        'Timestamp': timestamp,
        'Message': message
    })
    
    return {
        'statusCode': 200,
        'body': json.dumps({'status': 'Message stored'})
    }

def get_messages(event):
    room_id = event['queryStringParameters'].get('RoomID') if event['queryStringParameters'] else None
    
    if not room_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing RoomID'})
        }
    
    response = table.query(
        KeyConditionExpression=Key('RoomID').eq(room_id)
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'messages': response.get('Items', [])}, cls=DecimalEncoder)
    }

def update_message(event):
    body = json.loads(event['body'])
    room_id = body.get('RoomID')
    timestamp = body.get('Timestamp')
    message = body.get('Message')
    
    if not room_id or not timestamp or not message:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing parameters'})
        }
    
    table.update_item(
        Key={'RoomID': room_id, 'Timestamp': timestamp},
        UpdateExpression='SET Message = :message',
        ExpressionAttributeValues={':message': message}
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'status': 'Message updated'})
    }

def delete_message(event):
    body = json.loads(event['body'])
    room_id = body.get('RoomID')
    timestamp = body.get('Timestamp')
    
    if not room_id or not timestamp:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing parameters'})
        }
    
    table.delete_item(
        Key={'RoomID': room_id, 'Timestamp': timestamp}
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'status': 'Message deleted'})
    }