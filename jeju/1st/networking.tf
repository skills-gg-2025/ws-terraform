# Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# Hub VPC
resource "aws_vpc" "hub_vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hub-vpc"
  }
}

# App VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "app-vpc"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "hub_public_a" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = "172.16.10.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "hub-public-a"
  }
}

resource "aws_subnet" "hub_public_b" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = "172.16.20.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "hub-public-b"
  }
}

resource "aws_subnet" "hub_firewall_a" {
  vpc_id            = aws_vpc.hub_vpc.id
  cidr_block        = "172.16.30.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "hub-firewall-a"
  }
}

resource "aws_subnet" "hub_firewall_b" {
  vpc_id            = aws_vpc.hub_vpc.id
  cidr_block        = "172.16.40.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "hub-firewall-b"
  }
}

# App VPC Subnets
resource "aws_subnet" "app_public_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "192.168.10.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "app-public-a"
  }
}

resource "aws_subnet" "app_public_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "192.168.20.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "app-public-b"
  }
}

resource "aws_subnet" "app_private_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "192.168.30.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "app-private-a"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "192.168.40.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "app-private-b"
  }
}

resource "aws_subnet" "app_data_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "192.168.50.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "app-data-a"
  }
}

resource "aws_subnet" "app_data_b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "192.168.60.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "app-data-b"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = {
    Name = "hub-igw"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "app-igw"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_a" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.app_igw]

  tags = {
    Name = "nat-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.app_igw]

  tags = {
    Name = "nat-eip-b"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.app_public_a.id

  tags = {
    Name = "nat-gateway-a"
  }

  depends_on = [aws_internet_gateway.app_igw]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.app_public_b.id

  tags = {
    Name = "nat-gateway-b"
  }

  depends_on = [aws_internet_gateway.app_igw]
}

# Route Tables
resource "aws_route_table" "hub_public_rt" {
  vpc_id = aws_vpc.hub_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }

  tags = {
    Name = "hub-public-rt"
  }
}

resource "aws_route_table" "app_public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "app-public-rt"
  }
}

resource "aws_route_table" "app_private_a_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  route {
    cidr_block         = "172.16.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.hub_app_tgw.id
  }

  tags = {
    Name = "app-private-a-rt"
  }
}

resource "aws_route_table" "app_private_b_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  route {
    cidr_block         = "172.16.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.hub_app_tgw.id
  }

  tags = {
    Name = "app-private-b-rt"
  }
}

resource "aws_route_table" "app_data_rt" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "app-data-rt"
  }
}

resource "aws_route_table" "hub_firewall_rt" {
  vpc_id = aws_vpc.hub_vpc.id

  tags = {
    Name = "hub-firewall-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "hub_public_a" {
  subnet_id      = aws_subnet.hub_public_a.id
  route_table_id = aws_route_table.hub_public_rt.id
}

resource "aws_route_table_association" "hub_public_b" {
  subnet_id      = aws_subnet.hub_public_b.id
  route_table_id = aws_route_table.hub_public_rt.id
}

resource "aws_route_table_association" "hub_firewall_a" {
  subnet_id      = aws_subnet.hub_firewall_a.id
  route_table_id = aws_route_table.hub_firewall_rt.id
}

resource "aws_route_table_association" "hub_firewall_b" {
  subnet_id      = aws_subnet.hub_firewall_b.id
  route_table_id = aws_route_table.hub_firewall_rt.id
}

resource "aws_route_table_association" "app_public_a" {
  subnet_id      = aws_subnet.app_public_a.id
  route_table_id = aws_route_table.app_public_rt.id
}

resource "aws_route_table_association" "app_public_b" {
  subnet_id      = aws_subnet.app_public_b.id
  route_table_id = aws_route_table.app_public_rt.id
}

resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.app_private_a_rt.id
}

resource "aws_route_table_association" "app_private_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.app_private_b_rt.id
}

resource "aws_route_table_association" "app_data_a" {
  subnet_id      = aws_subnet.app_data_a.id
  route_table_id = aws_route_table.app_data_rt.id
}

resource "aws_route_table_association" "app_data_b" {
  subnet_id      = aws_subnet.app_data_b.id
  route_table_id = aws_route_table.app_data_rt.id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "hub_app_tgw" {
  description = "Transit Gateway for Hub and App VPC communication"

  tags = {
    Name = "hub-app-tgw"
  }
}

# Transit Gateway VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "hub_vpc_attachment" {
  subnet_ids         = [aws_subnet.hub_firewall_a.id, aws_subnet.hub_firewall_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.hub_app_tgw.id
  vpc_id             = aws_vpc.hub_vpc.id

  tags = {
    Name = "hub-vpc-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app_vpc_attachment" {
  subnet_ids         = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.hub_app_tgw.id
  vpc_id             = aws_vpc.app_vpc.id

  tags = {
    Name = "app-vpc-attachment"
  }
}

# Transit Gateway Routes (using default route table)
resource "aws_ec2_transit_gateway_route" "hub_to_app" {
  destination_cidr_block         = "192.168.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.hub_app_tgw.association_default_route_table_id
}

resource "aws_ec2_transit_gateway_route" "app_to_hub" {
  destination_cidr_block         = "172.16.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.hub_app_tgw.association_default_route_table_id
}

# Add Transit Gateway routes to VPC route tables
resource "aws_route" "hub_firewall_to_app" {
  route_table_id         = aws_route_table.hub_firewall_rt.id
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.hub_app_tgw.id
}

resource "aws_route" "hub_public_to_app" {
  route_table_id         = aws_route_table.hub_public_rt.id
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.hub_app_tgw.id
}

resource "aws_route" "app_public_to_hub" {
  route_table_id         = aws_route_table.app_public_rt.id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.hub_app_tgw.id
}



resource "aws_route" "app_data_to_hub" {
  route_table_id         = aws_route_table.app_data_rt.id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.hub_app_tgw.id
}