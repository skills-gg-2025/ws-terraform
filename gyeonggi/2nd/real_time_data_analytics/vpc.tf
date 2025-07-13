# VPC
resource "aws_vpc" "data_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "data-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "data_igw" {
  vpc_id = aws_vpc.data_vpc.id

  tags = {
    Name = "data-igw"
  }
}

# Public Subnets
resource "aws_subnet" "data_public_a" {
  vpc_id                  = aws_vpc.data_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "data-public-a"
  }
}

resource "aws_subnet" "data_public_b" {
  vpc_id                  = aws_vpc.data_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "data-public-b"
  }
}

# Private Subnets
resource "aws_subnet" "data_private_a" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "data-private-a"
  }
}

resource "aws_subnet" "data_private_b" {
  vpc_id            = aws_vpc.data_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "data-private-b"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "data-nat-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = {
    Name = "data-nat-eip-b"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "data_nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.data_public_a.id

  tags = {
    Name = "data-nat-a"
  }

  depends_on = [aws_internet_gateway.data_igw]
}

resource "aws_nat_gateway" "data_nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.data_public_b.id

  tags = {
    Name = "data-nat-b"
  }

  depends_on = [aws_internet_gateway.data_igw]
}

# Route Tables
resource "aws_route_table" "data_public" {
  vpc_id = aws_vpc.data_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.data_igw.id
  }

  tags = {
    Name = "data-public-rt"
  }
}

resource "aws_route_table" "data_private_a" {
  vpc_id = aws_vpc.data_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.data_nat_a.id
  }

  tags = {
    Name = "data-private-rt-a"
  }
}

resource "aws_route_table" "data_private_b" {
  vpc_id = aws_vpc.data_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.data_nat_b.id
  }

  tags = {
    Name = "data-private-rt-b"
  }
}

# Route Table Associations
resource "aws_route_table_association" "data_public_a" {
  subnet_id      = aws_subnet.data_public_a.id
  route_table_id = aws_route_table.data_public.id
}

resource "aws_route_table_association" "data_public_b" {
  subnet_id      = aws_subnet.data_public_b.id
  route_table_id = aws_route_table.data_public.id
}

resource "aws_route_table_association" "data_private_a" {
  subnet_id      = aws_subnet.data_private_a.id
  route_table_id = aws_route_table.data_private_a.id
}

resource "aws_route_table_association" "data_private_b" {
  subnet_id      = aws_subnet.data_private_b.id
  route_table_id = aws_route_table.data_private_b.id
}