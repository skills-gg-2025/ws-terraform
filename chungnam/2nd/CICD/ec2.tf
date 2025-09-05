# IAM Role for EC2 Instance
resource "aws_iam_role" "admin_role" {
  name = "admin-role"

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

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "admin_profile" {
  name = "admin-profile"
  role = aws_iam_role.admin_role.name
}

# Security Group for EC2 Instance
resource "aws_security_group" "instance_sg" {
  name        = "wsc2025-instance-sg"
  description = "Security group for wsc2025 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    Name = "wsc2025-instance-sg"
  }
}

# Generate SSH Key Pair
resource "tls_private_key" "wsc2025_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "wsc2025_key" {
  key_name   = "wsc2025-key"
  public_key = tls_private_key.wsc2025_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.wsc2025_key.private_key_pem
  filename = "wsc2025-key.pem"
  file_permission = "0600"
}

# EC2 Instance
resource "aws_instance" "wsc2025_instance" {
  ami                    = "ami-015927f8ee1bc0293"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.admin_profile.name
  key_name               = aws_key_pair.wsc2025_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.3/2025-04-17/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin
    
    # Create directories
    mkdir -p /home/ec2-user/k8s_file
    chown -R ec2-user:ec2-user /home/ec2-user/k8s_file
  EOF

  tags = {
    Name = "wsc2025-instance"
  }
}