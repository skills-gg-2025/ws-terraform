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
resource "aws_vpc" "wsi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wsi-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "wsi_igw" {
  vpc_id = aws_vpc.wsi_vpc.id

  tags = {
    Name = "wsi-igw"
  }
}

# Public Subnets
resource "aws_subnet" "wsi_public_subnet_a" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "wsi-public-subnet-a"
  }
}

resource "aws_subnet" "wsi_public_subnet_b" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "wsi-public-subnet-b"
  }
}

# Private Subnets
resource "aws_subnet" "wsi_private_subnet_a" {
  vpc_id            = aws_vpc.wsi_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "wsi-private-subnet-a"
  }
}

resource "aws_subnet" "wsi_private_subnet_b" {
  vpc_id            = aws_vpc.wsi_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "wsi-private-subnet-b"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "wsi_natgw_a_eip" {
  domain = "vpc"
  tags = {
    Name = "wsi-natgw-a-eip"
  }
}

resource "aws_eip" "wsi_natgw_b_eip" {
  domain = "vpc"
  tags = {
    Name = "wsi-natgw-b-eip"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "wsi_natgw_a" {
  allocation_id = aws_eip.wsi_natgw_a_eip.id
  subnet_id     = aws_subnet.wsi_public_subnet_a.id

  tags = {
    Name = "wsi-natgw-a"
  }

  depends_on = [aws_internet_gateway.wsi_igw]
}

resource "aws_nat_gateway" "wsi_natgw_b" {
  allocation_id = aws_eip.wsi_natgw_b_eip.id
  subnet_id     = aws_subnet.wsi_public_subnet_b.id

  tags = {
    Name = "wsi-natgw-b"
  }

  depends_on = [aws_internet_gateway.wsi_igw]
}

# Public Route Table
resource "aws_route_table" "wsi_public_rtb" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wsi_igw.id
  }

  tags = {
    Name = "wsi-public-rtb"
  }
}

# Private Route Tables
resource "aws_route_table" "wsi_private_rtb_a" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.wsi_natgw_a.id
  }

  tags = {
    Name = "wsi-private-rtb-a"
  }
}

resource "aws_route_table" "wsi_private_rtb_b" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.wsi_natgw_b.id
  }

  tags = {
    Name = "wsi-private-rtb-b"
  }
}

# Route Table Associations
resource "aws_route_table_association" "wsi_public_subnet_a_association" {
  subnet_id      = aws_subnet.wsi_public_subnet_a.id
  route_table_id = aws_route_table.wsi_public_rtb.id
}

resource "aws_route_table_association" "wsi_public_subnet_b_association" {
  subnet_id      = aws_subnet.wsi_public_subnet_b.id
  route_table_id = aws_route_table.wsi_public_rtb.id
}

resource "aws_route_table_association" "wsi_private_subnet_a_association" {
  subnet_id      = aws_subnet.wsi_private_subnet_a.id
  route_table_id = aws_route_table.wsi_private_rtb_a.id
}

resource "aws_route_table_association" "wsi_private_subnet_b_association" {
  subnet_id      = aws_subnet.wsi_private_subnet_b.id
  route_table_id = aws_route_table.wsi_private_rtb_b.id
}

# Security Groups
resource "aws_security_group" "wsi_bastion_sg" {
  name        = "wsi-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.wsi_vpc.id

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
    Name = "wsi-bastion-sg"
  }
}

resource "aws_security_group" "wsi_app_sg" {
  name        = "wsi-app-sg"
  description = "Security group for app instance"
  vpc_id      = aws_vpc.wsi_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.wsi_bastion_sg.id]
  }

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsi-app-sg"
  }
}

resource "aws_security_group" "wsi_efs_sg" {
  name        = "wsi-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.wsi_vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wsi_app_sg.id]
  }

  tags = {
    Name = "wsi-efs-sg"
  }
}

# Key Pair
resource "tls_private_key" "wsi_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "wsi_key" {
  key_name   = "wsi-key"
  public_key = tls_private_key.wsi_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.wsi_key.private_key_pem
  filename = "wsi-key.pem"
  file_permission = "0400"
}

# EC2 Instances
resource "aws_instance" "wsi_bastion" {
  ami                    = "ami-0c2d3e23e757b5d84"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.wsi_key.key_name
  subnet_id              = aws_subnet.wsi_public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.wsi_bastion_sg.id]

  tags = {
    Name = "wsi-bastion"
  }
}

resource "aws_instance" "wsi_app_instance" {
  ami                    = "ami-0c2d3e23e757b5d84"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.wsi_key.key_name
  subnet_id              = aws_subnet.wsi_private_subnet_a.id
  vpc_security_group_ids = [aws_security_group.wsi_app_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y amazon-efs-utils
              mkdir -p /mnt/efs
              echo "${aws_efs_file_system.wsi_efs.id}.efs.ap-northeast-2.amazonaws.com:/ /mnt/efs efs defaults,_netdev,tls,accesspoint=${aws_efs_access_point.wsi_ap.id}" >> /etc/fstab
              mount -a
              EOF

  tags = {
    Name = "wsi-app-instance"
  }

  depends_on = [aws_efs_file_system.wsi_efs, aws_efs_access_point.wsi_ap]
}

# EFS File System
resource "aws_efs_file_system" "wsi_efs" {
  creation_token   = "wsi-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  encrypted        = true

  tags = {
    Name = "wsi-efs"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "wsi_efs_mount_a" {
  file_system_id  = aws_efs_file_system.wsi_efs.id
  subnet_id       = aws_subnet.wsi_private_subnet_a.id
  security_groups = [aws_security_group.wsi_efs_sg.id]
}

resource "aws_efs_mount_target" "wsi_efs_mount_b" {
  file_system_id  = aws_efs_file_system.wsi_efs.id
  subnet_id       = aws_subnet.wsi_private_subnet_b.id
  security_groups = [aws_security_group.wsi_efs_sg.id]
}

# EFS Access Point
resource "aws_efs_access_point" "wsi_ap" {
  file_system_id = aws_efs_file_system.wsi_efs.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/app"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "wsi-ap"
  }
}

