# Egress VPC Subnets
resource "aws_subnet" "egress_public_a" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wsc2025-egress-public-sn-a"
  }
}

resource "aws_subnet" "egress_public_b" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wsc2025-egress-public-sn-b"
  }
}

resource "aws_subnet" "egress_peering_a" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wsc2025-egress-peering-sn-a"
  }
}

resource "aws_subnet" "egress_peering_b" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wsc2025-egress-peering-sn-b"
  }
}

resource "aws_subnet" "egress_firewall_a" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wsc2025-egress-firewall-sn-a"
  }
}

resource "aws_subnet" "egress_firewall_b" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wsc2025-egress-firewall-sn-b"
  }
}

# App VPC Subnets
resource "aws_subnet" "app_private_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "wsc2025-app-private-sn-a"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "wsc2025-app-private-sn-b"
  }
}