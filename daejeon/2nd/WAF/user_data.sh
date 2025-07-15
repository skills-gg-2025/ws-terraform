#!/bin/bash
yum update -y
yum install -y python3-pip

# Setup application
cd /home/ec2-user
mkdir -p app
cd app

# Copy application files
cat > app.py << 'EOF'
${app_py_content}
EOF

cat > requirements.txt << 'EOF'
${requirements_content}
EOF

# Install dependencies and start application
pip3 install -r requirements.txt
nohup python3 app.py > app.log 2>&1 &

chown -R ec2-user:ec2-user /home/ec2-user/app