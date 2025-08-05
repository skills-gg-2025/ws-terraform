# service-b
from flask import Flask, jsonify
import boto3
import datetime

app = Flask(__name__)

TABLE_NAME = "service-b-table"

# DynamoDB 클라이언트 생성 (앱 시작 시 생성)
dynamodb = boto3.resource("dynamodb", region_name="ap-southeast-1")
table = dynamodb.Table(TABLE_NAME)

@app.route("/api")
def api():
    now = datetime.datetime.now().isoformat()

    # 예시로 데이터 저장
    item = {
        "id": "example",
        "timestamp": now
    }
    table.put_item(Item=item)

    return jsonify({"message": "Hello from Service A", "time": now})

@app.route("/api/get")
def get_data():
    try:
        response = table.get_item(
            Key={
                "id": "example"
            }
        )
        item = response.get('Item')
        if item:
            return jsonify({"message": "data retrieved", "item": item})
        else:
            return jsonify({"message": "no data found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
