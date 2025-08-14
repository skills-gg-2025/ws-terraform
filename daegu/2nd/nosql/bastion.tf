# 키페어
resource "aws_key_pair" "chat_app" {
  key_name   = "chat-app-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCwWqlFOKujifNhLrN4KW8wSSUW2zIO0UPJZbiJ22ZIB44hhSvg44nF7jBJTZKAaG3KiaI6O0qgfWHxifnhBB7Vnz36N3Dub0dDUs/5RaP322kyn2wMYKCusg5wrY31xfHj6DWETliXRkZdTcHhTCiMGByjGH85gY8cbSn+PMUGBietNChZw16F5yEL7P264MGknh9/ZYqzLkvZZ3YgA3IBd3Li3RUU8wnug7G63xtnD5+lVe170neMGPs+UHH4OJgNLtDdoWOURmIXRSfuSfu9d5wYemBoVj8ThM1hAm00ghAneV+4/7+u/WfZ1QIrIVZIo8vSpB8f0+mMPb5Gh0gT administrator@3-8-07"
}

# Bastion EC2 인스턴스
resource "aws_instance" "bastion" {
  ami                    = "ami-0de716d6197524dd9"
  instance_type          = "t2.micro"
  key_name              = aws_key_pair.chat_app.key_name
  subnet_id             = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  
  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
yum update -y
yum install -y python3 python3-pip

# Flask 앱 파일 생성
cat > /home/ec2-user/app.py << 'APPEOF'
from flask import Flask, request, jsonify
import boto3
from datetime import datetime

app = Flask(__name__)

# DynamoDB 클라이언트 설정
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
APPEOF

# 패키지 설치
sudo -u ec2-user pip3 install --user flask boto3
chown ec2-user:ec2-user /home/ec2-user/app.py

# systemd 서비스 생성
cat > /etc/systemd/system/flask-app.service << SERVICEEOF
[Unit]
Description=Flask Chat App
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user
Environment=PATH=/home/ec2-user/.local/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 /home/ec2-user/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable flask-app
systemctl start flask-app

echo "User data script completed" >> /var/log/user-data.log
EOF
  
  tags = {
    Name = "chat-bastion"
  }
}