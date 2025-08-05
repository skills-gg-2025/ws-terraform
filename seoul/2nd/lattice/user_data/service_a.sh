#!/bin/bash
dnf update -y
dnf install -y python3 python3-pip

# Install Flask and requests
pip3 install flask requests

# Copy service-a.py from src directory
cat > /home/ec2-user/service-a.py << 'EOF'
# service-a
from flask import Flask, jsonify
import requests

app = Flask(__name__)

# 환경 변수에서 서비스 B의 URL을 가져옵니다.
import os
LATTICE_SERVICE_B_URL = os.environ.get('LATTICE_SERVICE_B_URL', 'http://localhost/api')

@app.route("/hello")
def hello():
    try:
        res = requests.get(LATTICE_SERVICE_B_URL, timeout=2)
        return res.text, res.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
EOF

# Set ownership
chown ec2-user:ec2-user /home/ec2-user/service-a.py

# Create systemd service
cat > /etc/systemd/system/service-a.service << 'EOF'
[Unit]
Description=Service A Flask App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ec2-user
Environment=LATTICE_SERVICE_B_URL=${lattice_service_url}
ExecStart=/usr/bin/python3 /home/ec2-user/service-a.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable service-a
systemctl start service-a