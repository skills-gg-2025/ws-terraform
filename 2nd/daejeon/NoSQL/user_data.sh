#!/bin/bash
yum update -y
yum install -y python3 python3-pip

# Flask 애플리케이션 설치
pip3 install flask boto3

# 애플리케이션 디렉토리 생성
mkdir -p /opt/account-app

# 애플리케이션 코드 배포
echo "${app_code}" | base64 -d > /opt/account-app/app.py

# 서비스 파일 생성
cat > /etc/systemd/system/account-app.service << EOF
[Unit]
Description=Account Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/account-app
ExecStart=/usr/bin/python3 /opt/account-app/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 서비스 시작
systemctl daemon-reload
systemctl enable account-app
systemctl start account-app