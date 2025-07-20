provider "aws" {
  region = "ap-northeast-1"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# VPC Configuration
resource "aws_vpc" "wsi_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "wsi-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "wsi_pub_sn_a" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "wsi-pub-sn-a"
  }
}

resource "aws_subnet" "wsi_pub_sn_c" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "wsi-pub-sn-c"
  }
}

# Private Subnets
resource "aws_subnet" "wsi_priv_sn_a" {
  vpc_id            = aws_vpc.wsi_vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "wsi-priv-sn-a"
  }
}

resource "aws_subnet" "wsi_priv_sn_c" {
  vpc_id            = aws_vpc.wsi_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "wsi-priv-sn-c"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "wsi_igw" {
  vpc_id = aws_vpc.wsi_vpc.id

  tags = {
    Name = "wsi-igw"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip_a" {
  domain = "vpc"
}

resource "aws_eip" "nat_eip_c" {
  domain = "vpc"
}

resource "aws_nat_gateway" "wsi_nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.wsi_pub_sn_a.id

  tags = {
    Name = "wsi-nat-gw-a"
  }
}

resource "aws_nat_gateway" "wsi_nat_gw_c" {
  allocation_id = aws_eip.nat_eip_c.id
  subnet_id     = aws_subnet.wsi_pub_sn_c.id

  tags = {
    Name = "wsi-nat-gw-c"
  }
}

# Route Tables
resource "aws_route_table" "wsi_pub_rt" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wsi_igw.id
  }

  tags = {
    Name = "wsi-pub-rt"
  }
}

resource "aws_route_table" "wsi_priv_rt_a" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.wsi_nat_gw_a.id
  }

  tags = {
    Name = "wsi-priv-rt-a"
  }
}

resource "aws_route_table" "wsi_priv_rt_c" {
  vpc_id = aws_vpc.wsi_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.wsi_nat_gw_c.id
  }

  tags = {
    Name = "wsi-priv-rt-c"
  }
}

# Route Table Associations
resource "aws_route_table_association" "pub_a_association" {
  subnet_id      = aws_subnet.wsi_pub_sn_a.id
  route_table_id = aws_route_table.wsi_pub_rt.id
}

resource "aws_route_table_association" "pub_c_association" {
  subnet_id      = aws_subnet.wsi_pub_sn_c.id
  route_table_id = aws_route_table.wsi_pub_rt.id
}

resource "aws_route_table_association" "priv_a_association" {
  subnet_id      = aws_subnet.wsi_priv_sn_a.id
  route_table_id = aws_route_table.wsi_priv_rt_a.id
}

resource "aws_route_table_association" "priv_c_association" {
  subnet_id      = aws_subnet.wsi_priv_sn_c.id
  route_table_id = aws_route_table.wsi_priv_rt_c.id
}