#!/bin/bash
dnf update -y
dnf install -y python3 python3-pip

# Install Flask and boto3
pip3 install flask boto3

# Copy service-b.py from src directory
cat > /home/ec2-user/service-b.py << 'EOF'
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
EOF

# Set ownership
chown ec2-user:ec2-user /home/ec2-user/service-b.py

# Create systemd service
cat > /etc/systemd/system/service-b.service << 'EOF'
[Unit]
Description=Service B Flask App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ec2-user
ExecStart=/usr/bin/python3 /home/ec2-user/service-b.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable service-b
systemctl start service-b