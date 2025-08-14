from flask import Flask, request, jsonify
import boto3
import os
from datetime import datetime

app = Flask(__name__)

# DynamoDB 또는 DAX 클라이언트 설정
USE_DAX = os.environ.get('USE_DAX', 'false').lower() == 'true'

if USE_DAX:
    import amazondax
    dax_endpoint = os.environ.get('DAX_ENDPOINT')  # ex) 'dax://<endpoint>'
    client = amazondax.AmazonDaxClient(region_name='us-east-1', endpoints=[dax_endpoint])
else:
    client = boto3.resource('dynamodb', region_name='us-east-1')

table = client.Table('chat-messages')

@app.route('/healthcheck', methods=['GET'])
def healthcheck():
    return jsonify({'status': 'ok'}), 200

@app.route('/send-message', methods=['POST'])
def send_message():
    data = request.get_json()
    room_id = data.get('RoomID')
    timestamp = datetime.utcnow().isoformat()
    message = data.get('Message')

    if not room_id or not message:
        return jsonify({'error': 'Missing parameters'}), 400

    table.put_item(Item={
        'RoomID': room_id,
        'Timestamp': timestamp,
        'Message': message
    })
    return jsonify({'status': 'Message stored'}), 200

@app.route('/get-messages', methods=['GET'])
def get_messages():
    room_id = request.args.get('RoomID')
    if not room_id:
        return jsonify({'error': 'Missing RoomID'}), 400

    response = table.query(
        KeyConditionExpression=boto3.dynamodb.conditions.Key('RoomID').eq(room_id)
    )
    return jsonify({'messages': response.get('Items', [])}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
