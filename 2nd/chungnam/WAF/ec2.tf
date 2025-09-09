# IAM Role for EC2 to use Systems Manager
resource "aws_iam_role" "ec2_ssm_role" {
  name = "wsc2025-waf-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_admin_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "wsc2025-waf-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Security Group for instances
resource "aws_security_group" "app_sg" {
  name        = "wsc2025-waf-app-sg"
  description = "Security group for WAF app instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsc2025-waf-app-sg"
  }
}

# Bastion Instance
resource "aws_instance" "waf_bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  availability_zone      = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-ssm-agent
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              EOF

  tags = {
    Name = "waf-bastion"
  }
}

# App Server Instance
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.small"
  availability_zone           = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_ssm_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-ssm-agent python3 python3-pip
              systemctl enable amazon-ssm-agent
              systemctl start amazon-ssm-agent
              
              # Create app directory
              mkdir -p /opt/app/utils
              
              # Copy application files
              cat > /opt/app/main.py << 'PYEOF'
${file("${path.module}/deploy_file/main.py")}
PYEOF

              cat > /opt/app/utils/query_builder.py << 'PYEOF'
${file("${path.module}/deploy_file/utils/query_builder.py")}
PYEOF

              # Install Flask
              pip3 install flask
              
              # Create systemd service
              cat > /etc/systemd/system/waf-app.service << 'SVCEOF'
[Unit]
Description=WAF Test Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
SVCEOF

              # Start the service
              systemctl daemon-reload
              systemctl enable waf-app
              systemctl start waf-app
              EOF

  tags = {
    Name = "wsc2025-app-server"
  }
}