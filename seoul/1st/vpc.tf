# Hub VPC
resource "aws_vpc" "wsk_hub" {
  cidr_block           = "10.76.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wsk-hub"
  }
}

# App VPC
resource "aws_vpc" "wsk_app" {
  cidr_block           = "10.88.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wsk-app"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "wsk_hub_pub_a" {
  vpc_id                  = aws_vpc.wsk_hub.id
  cidr_block              = "10.76.10.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "wsk-hub-pub-a"
  }
}

resource "aws_subnet" "wsk_hub_pub_b" {
  vpc_id                  = aws_vpc.wsk_hub.id
  cidr_block              = "10.76.20.0/24"
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "wsk-hub-pub-b"
  }
}

# App VPC Subnets
resource "aws_subnet" "wsk_app_pub_a" {
  vpc_id                  = aws_vpc.wsk_app.id
  cidr_block              = "10.88.1.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "wsk-app-pub-a"
  }
}

resource "aws_subnet" "wsk_app_pub_b" {
  vpc_id                  = aws_vpc.wsk_app.id
  cidr_block              = "10.88.2.0/24"
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "wsk-app-pub-b"
  }
}

resource "aws_subnet" "wsk_app_priv_a" {
  vpc_id            = aws_vpc.wsk_app.id
  cidr_block        = "10.88.3.0/24"
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wsk-app-priv-a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "wsk_app_priv_b" {
  vpc_id            = aws_vpc.wsk_app.id
  cidr_block        = "10.88.4.0/24"
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "wsk-app-priv-b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "wsk_app_db_a" {
  vpc_id            = aws_vpc.wsk_app.id
  cidr_block        = "10.88.5.0/24"
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wsk-app-db-a"
  }
}

resource "aws_subnet" "wsk_app_db_b" {
  vpc_id            = aws_vpc.wsk_app.id
  cidr_block        = "10.88.6.0/24"
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "wsk-app-db-b"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "wsk_hub_igw" {
  vpc_id = aws_vpc.wsk_hub.id

  tags = {
    Name = "wsk-hub-igw"
  }
}

resource "aws_internet_gateway" "wsk_app_igw" {
  vpc_id = aws_vpc.wsk_app.id

  tags = {
    Name = "wsk-app-igw"
  }
}

# Egress Only Internet Gateway
resource "aws_egress_only_internet_gateway" "wsk_app_eigw" {
  vpc_id = aws_vpc.wsk_app.id

  tags = {
    Name = "wsk-app-eigw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "wsk_app_natgw_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.wsk_app_igw]
}

# NAT Gateway
resource "aws_nat_gateway" "wsk_app_natgw" {
  allocation_id = aws_eip.wsk_app_natgw_eip.id
  subnet_id     = aws_subnet.wsk_app_pub_a.id

  tags = {
    Name = "wsk-app-natgw"
  }

  depends_on = [aws_internet_gateway.wsk_app_igw]
}

# Route Tables
resource "aws_route_table" "wsk_hub_pub_rt" {
  vpc_id = aws_vpc.wsk_hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wsk_hub_igw.id
  }

  route {
    cidr_block                = "10.88.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.wsk_vpcp.id
  }

  tags = {
    Name = "wsk-hub-pub-rt"
  }
}

resource "aws_route_table" "wsk_app_pub_rt" {
  vpc_id = aws_vpc.wsk_app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wsk_app_igw.id
  }

  tags = {
    Name = "wsk-app-pub-rt"
  }
}

resource "aws_route_table" "wsk_app_priv_rt" {
  vpc_id = aws_vpc.wsk_app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.wsk_app_natgw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.wsk_app_eigw.id
  }

  route {
    cidr_block                = "10.76.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.wsk_vpcp.id
  }

  tags = {
    Name = "wsk-app-priv-rt"
  }
}

resource "aws_route_table" "wsk_app_db_rt" {
  vpc_id = aws_vpc.wsk_app.id

  route {
    cidr_block                = "10.76.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.wsk_vpcp.id
  }

  tags = {
    Name = "wsk-app-db-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "wsk_hub_pub_a" {
  subnet_id      = aws_subnet.wsk_hub_pub_a.id
  route_table_id = aws_route_table.wsk_hub_pub_rt.id
}

resource "aws_route_table_association" "wsk_hub_pub_b" {
  subnet_id      = aws_subnet.wsk_hub_pub_b.id
  route_table_id = aws_route_table.wsk_hub_pub_rt.id
}

resource "aws_route_table_association" "wsk_app_pub_a" {
  subnet_id      = aws_subnet.wsk_app_pub_a.id
  route_table_id = aws_route_table.wsk_app_pub_rt.id
}

resource "aws_route_table_association" "wsk_app_pub_b" {
  subnet_id      = aws_subnet.wsk_app_pub_b.id
  route_table_id = aws_route_table.wsk_app_pub_rt.id
}

resource "aws_route_table_association" "wsk_app_priv_a" {
  subnet_id      = aws_subnet.wsk_app_priv_a.id
  route_table_id = aws_route_table.wsk_app_priv_rt.id
}

resource "aws_route_table_association" "wsk_app_priv_b" {
  subnet_id      = aws_subnet.wsk_app_priv_b.id
  route_table_id = aws_route_table.wsk_app_priv_rt.id
}

resource "aws_route_table_association" "wsk_app_db_a" {
  subnet_id      = aws_subnet.wsk_app_db_a.id
  route_table_id = aws_route_table.wsk_app_db_rt.id
}

resource "aws_route_table_association" "wsk_app_db_b" {
  subnet_id      = aws_subnet.wsk_app_db_b.id
  route_table_id = aws_route_table.wsk_app_db_rt.id
}