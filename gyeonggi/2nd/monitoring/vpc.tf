// VPC Configuration
resource "aws_vpc" "moni_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "moni-vpc"
  }
}

// Public Subnets
resource "aws_subnet" "moni_public_a" {
  vpc_id                  = aws_vpc.moni_vpc.id
  cidr_block              = "10.100.1.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "moni-public-a"
  }
}

resource "aws_subnet" "moni_public_b" {
  vpc_id                  = aws_vpc.moni_vpc.id
  cidr_block              = "10.100.2.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "moni-public-b"
  }
}

// Private Subnets
resource "aws_subnet" "moni_private_a" {
  vpc_id            = aws_vpc.moni_vpc.id
  cidr_block        = "10.100.3.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "moni-private-a"
  }
}

resource "aws_subnet" "moni_private_b" {
  vpc_id            = aws_vpc.moni_vpc.id
  cidr_block        = "10.100.4.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "moni-private-b"
  }
}

// Internet Gateway
resource "aws_internet_gateway" "moni_igw" {
  vpc_id = aws_vpc.moni_vpc.id

  tags = {
    Name = "moni-igw"
  }
}

// Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "moni-nat-eip-a"
  }
}

resource "aws_eip" "nat_eip_b" {
  domain = "vpc"

  tags = {
    Name = "moni-nat-eip-b"
  }
}

// NAT Gateways
resource "aws_nat_gateway" "moni_nat_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.moni_public_a.id

  tags = {
    Name = "moni-nat-a"
  }
}

resource "aws_nat_gateway" "moni_nat_b" {
  allocation_id = aws_eip.nat_eip_b.id
  subnet_id     = aws_subnet.moni_public_b.id

  tags = {
    Name = "moni-nat-b"
  }
}

// Route Tables
resource "aws_route_table" "moni_public_rt" {
  vpc_id = aws_vpc.moni_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.moni_igw.id
  }

  tags = {
    Name = "moni-public-rt"
  }
}

resource "aws_route_table" "moni_private_rt_a" {
  vpc_id = aws_vpc.moni_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.moni_nat_a.id
  }

  tags = {
    Name = "moni-private-rt-a"
  }
}

resource "aws_route_table" "moni_private_rt_b" {
  vpc_id = aws_vpc.moni_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.moni_nat_b.id
  }

  tags = {
    Name = "moni-private-rt-b"
  }
}

// Route Table Associations
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.moni_public_a.id
  route_table_id = aws_route_table.moni_public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.moni_public_b.id
  route_table_id = aws_route_table.moni_public_rt.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.moni_private_a.id
  route_table_id = aws_route_table.moni_private_rt_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.moni_private_b.id
  route_table_id = aws_route_table.moni_private_rt_b.id
}