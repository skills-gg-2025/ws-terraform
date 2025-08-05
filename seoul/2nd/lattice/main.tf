terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.8.20250721.2-kernel-6.1-x86_64"]
  }
}

# VPC A
resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "VPC-A"
  }
}

# VPC B
resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "VPC-B"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags = {
    Name = "IGW-A"
  }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags = {
    Name = "IGW-B"
  }
}

# Subnets VPC A
resource "aws_subnet" "va_pub_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "va-pub-a"
  }
}

resource "aws_subnet" "va_priv_a" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-southeast-1a"
  tags = {
    Name = "va-priv-a"
  }
}

# Subnets VPC B
resource "aws_subnet" "vb_pub_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "vb-pub-b"
  }
}

resource "aws_subnet" "vb_priv_b" {
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = "ap-southeast-1b"
  tags = {
    Name = "vb-priv-b"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "NAT-A-EIP"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = {
    Name = "NAT-B-EIP"
  }
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  domain = "vpc"
  tags = {
    Name = "Bastion-EIP"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.va_pub_a.id
  tags = {
    Name = "NAT-A"
  }
  depends_on = [aws_internet_gateway.igw_a]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.vb_pub_b.id
  tags = {
    Name = "NAT-B"
  }
  depends_on = [aws_internet_gateway.igw_b]
}

# Route Tables
resource "aws_route_table" "public_a" {
  vpc_id = aws_vpc.vpc_a.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }
  tags = {
    Name = "Public-A-RT"
  }
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.vpc_a.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
  tags = {
    Name = "Private-A-RT"
  }
}

resource "aws_route_table" "public_b" {
  vpc_id = aws_vpc.vpc_b.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }
  tags = {
    Name = "Public-B-RT"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.vpc_b.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }
  tags = {
    Name = "Private-B-RT"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.va_pub_a.id
  route_table_id = aws_route_table.public_a.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.va_priv_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.vb_pub_b.id
  route_table_id = aws_route_table.public_b.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.vb_priv_b.id
  route_table_id = aws_route_table.private_b.id
}

# Security Groups
resource "aws_security_group" "bastion" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.vpc_a.id

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
    Name = "bastion-sg"
  }
}

resource "aws_security_group" "service_a" {
  name_prefix = "service-a-sg"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "service-a-sg"
  }
}

resource "aws_security_group" "service_b" {
  name_prefix = "service-b-sg"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16", "10.2.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["169.254.171.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "service-b-sg"
  }
}

# IAM Role for Bastion
resource "aws_iam_role" "bastion_role" {
  name = "bastion-role"

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

resource "aws_iam_role_policy_attachment" "bastion_admin" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# IAM Role for Service B (DynamoDB access)
resource "aws_iam_role" "service_b_role" {
  name = "service-b-role"

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

resource "aws_iam_role_policy" "service_b_dynamodb" {
  name = "service-b-dynamodb-policy"
  role = aws_iam_role.service_b_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.service_b_table.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "service_b_profile" {
  name = "service-b-profile"
  role = aws_iam_role.service_b_role.name
}

# DynamoDB Table
resource "aws_dynamodb_table" "service_b_table" {
  name           = "service-b-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "service-b-table"
  }
}

# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "lattice_net" {
  name = "lattice-net"
  tags = {
    Name = "lattice-net"
  }
}

# VPC Lattice Service Network VPC Association for VPC A
resource "aws_vpclattice_service_network_vpc_association" "vpc_a_association" {
  vpc_identifier             = aws_vpc.vpc_a.id
  service_network_identifier = aws_vpclattice_service_network.lattice_net.id
}

# VPC Lattice Service Network VPC Association for VPC B
resource "aws_vpclattice_service_network_vpc_association" "vpc_b_association" {
  vpc_identifier             = aws_vpc.vpc_b.id
  service_network_identifier = aws_vpclattice_service_network.lattice_net.id
}

# VPC Lattice Service
resource "aws_vpclattice_service" "service_b_lattice" {
  name = "service-b-lattice"
  tags = {
    Name = "service-b-lattice"
  }
}

# VPC Lattice Target Group
resource "aws_vpclattice_target_group" "service_b_tg" {
  name = "service-b-tg"
  type = "INSTANCE"

  config {
    vpc_identifier = aws_vpc.vpc_b.id
    port           = 80
    protocol       = "HTTP"
    
    health_check {
      enabled                       = true
      health_check_interval_seconds = 30
      health_check_timeout_seconds  = 5
      healthy_threshold_count       = 2
      matcher {
        value = "200"
      }
      path                         = "/api"
      protocol                     = "HTTP"
      protocol_version             = "HTTP1"
      unhealthy_threshold_count    = 2
    }
  }

  tags = {
    Name = "service-b-tg"
  }
}

# VPC Lattice Listener
resource "aws_vpclattice_listener" "service_b_listener" {
  name               = "service-b-listener"
  protocol           = "HTTP"
  port               = 80
  service_identifier = aws_vpclattice_service.service_b_lattice.id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.service_b_tg.id
      }
    }
  }

  tags = {
    Name = "service-b-listener"
  }
}

# VPC Lattice Service Network Service Association
resource "aws_vpclattice_service_network_service_association" "service_b_association" {
  service_identifier         = aws_vpclattice_service.service_b_lattice.id
  service_network_identifier = aws_vpclattice_service_network.lattice_net.id

  tags = {
    Name = "service-b-association"
  }
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "main-key"
  public_key = var.public_key
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id             = aws_subnet.va_pub_a.id
  iam_instance_profile  = aws_iam_instance_profile.bastion_profile.name

  user_data = file("user_data/bastion.sh")

  tags = {
    Name = "lat-bastion"
  }
}

# Bastion EIP Association
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# Service A Instance
resource "aws_instance" "service_a" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.service_a.id]
  subnet_id             = aws_subnet.va_priv_a.id

  user_data = templatefile("user_data/service_a.sh", {
    lattice_service_url = "http://${aws_vpclattice_service.service_b_lattice.dns_entry[0].domain_name}/api"
  })

  tags = {
    Name = "service-a-ec2"
  }

  depends_on = [aws_vpclattice_service.service_b_lattice]
}

# Service B Instance
resource "aws_instance" "service_b" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.service_b.id]
  subnet_id             = aws_subnet.vb_priv_b.id
  iam_instance_profile  = aws_iam_instance_profile.service_b_profile.name

  user_data = file("user_data/service_b.sh")

  tags = {
    Name = "service-b-ec2"
  }
}

# VPC Lattice Target Group Attachment
resource "aws_vpclattice_target_group_attachment" "service_b" {
  target_group_identifier = aws_vpclattice_target_group.service_b_tg.id

  target {
    id   = aws_instance.service_b.id
    port = 80
  }
}