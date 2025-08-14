terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gac-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gac-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "gac-public-subnet-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "gac-public-subnet-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "gac-private-subnet-1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "gac-private-subnet-2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "gac-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "gac-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "gac-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "gac-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# KMS Key
resource "aws_kms_key" "gac_key" {
  description             = "KMS key for GAC resources"
  deletion_window_in_days = 7

  tags = {
    Name = "gac-key"
  }
}

resource "aws_kms_alias" "gac_key_alias" {
  name          = "alias/gac-key"
  target_key_id = aws_kms_key.gac_key.key_id
}

# ECR Repository
resource "aws_ecr_repository" "gac_app" {
  name                 = "gac-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.gac_key.arn
  }

  tags = {
    Name = "gac-app"
  }
}

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

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "admin_profile" {
  name = "admin-profile"
  role = aws_iam_role.admin_role.name
}

# Security Group for EC2 Instance
resource "aws_security_group" "instance_sg" {
  name        = "gac-instance-sg"
  description = "Security group for gac instance"
  vpc_id      = aws_vpc.main.id

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
    Name = "gac-instance-sg"
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

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
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
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2025-05-01/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin
  EOF

  tags = {
    Name = "gac-bastion"
  }
}

# GitHub Actions Runner Instance
resource "aws_instance" "gac_runner" {
  ami                    = "ami-0c2acfcb2ac4d02a0"
  instance_type          = "t3.medium"
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
    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2025-05-01/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin
  EOF

  tags = {
    Name = "gac-runner"
  }
}