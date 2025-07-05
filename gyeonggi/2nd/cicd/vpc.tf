# VPC
resource "aws_vpc" "cicd_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cicd-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "cicd_igw" {
  vpc_id = aws_vpc.cicd_vpc.id

  tags = {
    Name = "cicd-igw"
  }
}

# Public Subnets
resource "aws_subnet" "cicd_public_a" {
  vpc_id                  = aws_vpc.cicd_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cicd-public-a"
  }
}

resource "aws_subnet" "cicd_public_b" {
  vpc_id                  = aws_vpc.cicd_vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "cicd-public-b"
  }
}

# Private Subnets
resource "aws_subnet" "cicd_private_a" {
  vpc_id            = aws_vpc.cicd_vpc.id
  cidr_block        = "10.0.111.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "cicd-private-a"
  }
}

resource "aws_subnet" "cicd_private_b" {
  vpc_id            = aws_vpc.cicd_vpc.id
  cidr_block        = "10.0.222.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "cicd-private-b"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "cicd_nat_a" {
  domain = "vpc"
  tags = {
    Name = "cicd-nat-a-eip"
  }
}

resource "aws_eip" "cicd_nat_b" {
  domain = "vpc"
  tags = {
    Name = "cicd-nat-b-eip"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "cicd_nat_a" {
  allocation_id = aws_eip.cicd_nat_a.id
  subnet_id     = aws_subnet.cicd_public_a.id

  tags = {
    Name = "cicd-nat-a"
  }
}

resource "aws_nat_gateway" "cicd_nat_b" {
  allocation_id = aws_eip.cicd_nat_b.id
  subnet_id     = aws_subnet.cicd_public_b.id

  tags = {
    Name = "cicd-nat-b"
  }
}

# Route Tables
resource "aws_route_table" "cicd_public" {
  vpc_id = aws_vpc.cicd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cicd_igw.id
  }

  tags = {
    Name = "cicd-public-rt"
  }
}

resource "aws_route_table" "cicd_private_a" {
  vpc_id = aws_vpc.cicd_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cicd_nat_a.id
  }

  tags = {
    Name = "cicd-private-a-rt"
  }
}

resource "aws_route_table" "cicd_private_b" {
  vpc_id = aws_vpc.cicd_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cicd_nat_b.id
  }

  tags = {
    Name = "cicd-private-b-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "cicd_public_a" {
  subnet_id      = aws_subnet.cicd_public_a.id
  route_table_id = aws_route_table.cicd_public.id
}

resource "aws_route_table_association" "cicd_public_b" {
  subnet_id      = aws_subnet.cicd_public_b.id
  route_table_id = aws_route_table.cicd_public.id
}

resource "aws_route_table_association" "cicd_private_a" {
  subnet_id      = aws_subnet.cicd_private_a.id
  route_table_id = aws_route_table.cicd_private_a.id
}

resource "aws_route_table_association" "cicd_private_b" {
  subnet_id      = aws_subnet.cicd_private_b.id
  route_table_id = aws_route_table.cicd_private_b.id
}