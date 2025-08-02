# Key Pair for Bastion
resource "aws_key_pair" "skills_log_bastion_key" {
  key_name   = "skills-log-bastion-key"
  public_key = file("${path.module}/src/id_rsa.pub")

  tags = {
    Name = "skills-log-bastion-key"
  }
}

# IAM Role for Bastion
resource "aws_iam_role" "skills_log_bastion_role" {
  name = "skills-log-bastion-role"

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

  tags = {
    Name = "skills-log-bastion-role"
  }
}

# Attach AdministratorAccess policy to the role
resource "aws_iam_role_policy_attachment" "skills_log_bastion_admin_policy" {
  role       = aws_iam_role.skills_log_bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance Profile for Bastion
resource "aws_iam_instance_profile" "skills_log_bastion_profile" {
  name = "skills-log-bastion-profile"
  role = aws_iam_role.skills_log_bastion_role.name

  tags = {
    Name = "skills-log-bastion-profile"
  }
}

# Security Group for Bastion
resource "aws_security_group" "skills_log_bastion_sg" {
  name        = "skills-log-bastion-sg"
  description = "Security group for bastion server"
  vpc_id      = aws_vpc.skills_log_vpc.id

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
    Name = "skills-log-bastion-sg"
  }
}

# User data script for Bastion
locals {
  bastion_user_data = <<-EOF
    #!/bin/bash
    yum update -y
    
    # Install awscli v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    # Install curl and jq
    yum install -y curl jq
    
    # Install Docker
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
  EOF
}

# Bastion EC2 Instance
resource "aws_instance" "skills_log_bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.skills_log_bastion_key.key_name
  vpc_security_group_ids = [aws_security_group.skills_log_bastion_sg.id]
  subnet_id              = aws_subnet.skills_log_pub_a.id
  iam_instance_profile   = aws_iam_instance_profile.skills_log_bastion_profile.name

  user_data = base64encode(local.bastion_user_data)

  tags = {
    Name = "skills-log-bastion"
  }
}

# Data source for Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}