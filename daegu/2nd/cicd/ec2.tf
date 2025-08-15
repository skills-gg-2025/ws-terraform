resource "aws_instance" "ci_app_server" {
  ami                    = "ami-0061376a80017c383"
  instance_type          = "t2.micro"
  key_name              = aws_key_pair.ci_app_keypair.key_name
  vpc_security_group_ids = [aws_security_group.ci_app_sg.id]
  subnet_id             = aws_subnet.public.id

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y python3 python3-pip git
mkdir -p /home/ec2-user/app
echo "flask" > /home/ec2-user/app/requirements.txt
cat > /home/ec2-user/app/server.py << 'PYEOF'
from flask import Flask
app = Flask(__name__)

@app.route('/health')
def health():
    return "OK", 200

@app.route('/version')
def version():
    return {"version": "1.0.0"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYEOF
chown -R ec2-user:ec2-user /home/ec2-user/app
cd /home/ec2-user/app
pip3 install flask

cat > /etc/systemd/system/svc.service << 'SEOF'
[Unit]
Description=foo/bar service

[Service]
Type=simple
ExecStart=python3 /home/ec2-user/app/server.py
Restart=on-failure
StandardOutput=file:/var/log/flask.log
StandardError=file:/var/log/flask.log

[Install]
WantedBy=multi-user.target
SEOF
systemctl daemon-reload
systemctl start svc
systemctl enable svc
EOF

  tags = {
    Name = "CIAppServer"
  }
}