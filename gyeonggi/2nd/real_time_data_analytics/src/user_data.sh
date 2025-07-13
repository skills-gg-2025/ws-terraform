#!/bin/bash
yum update -y
yum install -y python3-pip

# Install Flask
pip3 install flask

# Install Fluent Bit
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh

# Create Fluent Bit config
mkdir -p /etc/fluent-bit
cat > /etc/fluent-bit/parsers.conf << 'EOL'
[PARSER]
    Name        app_log
    Format      regex
    Regex       ^\[(?<event_time>[^\]]+)\] (?<level>\w+) (?<method>\w+) (?<path>\S+) (?<status_code>\d+)$
EOL

cat > /etc/fluent-bit/fluent-bit.conf << 'EOL'
[SERVICE]
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf

[INPUT]
    Name              tail
    Path              /home/ec2-user/app.log
    Parser            app_log

[OUTPUT]
    Name              kinesis_streams
    Match             *
    region            ap-southeast-1
    stream            input-stream
EOL

# Copy app.py to home directory
cp /opt/app.py /home/ec2-user/app.py
chown ec2-user:ec2-user /home/ec2-user/app.py

# Start Flask application with nohup as ec2-user
su - ec2-user -c "cd /home/ec2-user && nohup python3 app.py > app.log 2>&1 &"

# Start Fluent Bit
systemctl enable fluent-bit
systemctl start fluent-bit