# Egress VPC
resource "aws_vpc" "egress" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wsc2025-egress-vpc"
  }
}

# App VPC
resource "aws_vpc" "app" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wsc2025-app-vpc"
  }
}

# Internet Gateway for Egress VPC
resource "aws_internet_gateway" "egress_igw" {
  vpc_id = aws_vpc.egress.id

  tags = {
    Name = "wsc2025-egress-igw"
  }
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "app_to_egress" {
  peer_vpc_id = aws_vpc.egress.id
  vpc_id      = aws_vpc.app.id
  auto_accept = true

  tags = {
    Name = "wsc2025-app-to-egress-peering"
  }
}