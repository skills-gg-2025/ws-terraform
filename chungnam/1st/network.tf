# Hub VPC
resource "aws_vpc" "hub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "wsc2025-hub-vpc"
  }
}

# Application VPC
resource "aws_vpc" "app" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "wsc2025-app-vpc"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub.id
  
  tags = {
    Name = "wsc2025-hub-igw"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app.id
  
  tags = {
    Name = "wsc2025-app-igw"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "hub_pub_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "wsc2025-hub-pub-sn-a"
  }
}

resource "aws_subnet" "hub_pub_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = {
    Name = "wsc2025-hub-pub-sn-b"
  }
}

# Application VPC Subnets
resource "aws_subnet" "app_pub_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "wsc2025-app-pub-sn-a"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "app_pub_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = {
    Name = "wsc2025-app-pub-sn-b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "app_priv_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "wsc2025-app-priv-sn-a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "app_priv_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = {
    Name = "wsc2025-app-priv-sn-b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "app_db_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "wsc2025-app-db-sn-a"
  }
}

resource "aws_subnet" "app_db_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "172.16.5.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = {
    Name = "wsc2025-app-db-sn-b"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_a" {
  domain = "vpc"
  
  tags = {
    Name = "wsc2025-app-natgw-a-eip"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  
  tags = {
    Name = "wsc2025-app-natgw-b-eip"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "app_nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.app_pub_a.id
  
  tags = {
    Name = "wsc2025-app-natgw-a"
  }
  
  depends_on = [aws_internet_gateway.app_igw]
}

resource "aws_nat_gateway" "app_nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.app_pub_b.id
  
  tags = {
    Name = "wsc2025-app-natgw-b"
  }
  
  depends_on = [aws_internet_gateway.app_igw]
}

# Route Tables
resource "aws_route_table" "hub_pub_rt" {
  vpc_id = aws_vpc.hub.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }
  
  tags = {
    Name = "wsc2025-hub-pub-rt"
  }
}

resource "aws_route_table" "app_pub_rt" {
  vpc_id = aws_vpc.app.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }
  
  tags = {
    Name = "wsc2025-app-pub-rt"
  }
}

resource "aws_route_table" "app_priv_rt_a" {
  vpc_id = aws_vpc.app.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_a.id
  }
  
  tags = {
    Name = "wsc2025-app-priv-rt-a"
  }
}

resource "aws_route_table" "app_priv_rt_b" {
  vpc_id = aws_vpc.app.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_b.id
  }
  
  tags = {
    Name = "wsc2025-app-priv-rt-b"
  }
}

resource "aws_route_table" "app_db_rt" {
  vpc_id = aws_vpc.app.id
  
  tags = {
    Name = "wsc2025-app-db-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "hub_pub_a" {
  subnet_id      = aws_subnet.hub_pub_a.id
  route_table_id = aws_route_table.hub_pub_rt.id
}

resource "aws_route_table_association" "hub_pub_b" {
  subnet_id      = aws_subnet.hub_pub_b.id
  route_table_id = aws_route_table.hub_pub_rt.id
}

resource "aws_route_table_association" "app_pub_a" {
  subnet_id      = aws_subnet.app_pub_a.id
  route_table_id = aws_route_table.app_pub_rt.id
}

resource "aws_route_table_association" "app_pub_b" {
  subnet_id      = aws_subnet.app_pub_b.id
  route_table_id = aws_route_table.app_pub_rt.id
}

resource "aws_route_table_association" "app_priv_a" {
  subnet_id      = aws_subnet.app_priv_a.id
  route_table_id = aws_route_table.app_priv_rt_a.id
}

resource "aws_route_table_association" "app_priv_b" {
  subnet_id      = aws_subnet.app_priv_b.id
  route_table_id = aws_route_table.app_priv_rt_b.id
}

resource "aws_route_table_association" "app_db_a" {
  subnet_id      = aws_subnet.app_db_a.id
  route_table_id = aws_route_table.app_db_rt.id
}

resource "aws_route_table_association" "app_db_b" {
  subnet_id      = aws_subnet.app_db_b.id
  route_table_id = aws_route_table.app_db_rt.id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "WSC2025 Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  tags = {
    Name = "wsc2025-tgw"
  }
}

# Transit Gateway Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids                                      = [aws_subnet.hub_pub_a.id, aws_subnet.hub_pub_b.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.hub.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = "wsc2025-hub-tgat"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  subnet_ids                                      = [aws_subnet.app_priv_a.id, aws_subnet.app_priv_b.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.app.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  
  tags = {
    Name = "wsc2025-app-tgat"
  }
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  
  tags = {
    Name = "wsc2025-tgw-rt"
  }
}

# Transit Gateway Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_association" "app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Transit Gateway Routes
resource "aws_ec2_transit_gateway_route" "hub_to_app" {
  destination_cidr_block         = "172.16.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route" "app_to_hub" {
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# Add TGW routes to VPC route tables
resource "aws_route" "hub_to_tgw" {
  route_table_id         = aws_route_table.hub_pub_rt.id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.hub]
}

resource "aws_route" "app_priv_to_tgw_a" {
  route_table_id         = aws_route_table.app_priv_rt_a.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app]
}

resource "aws_route" "app_priv_to_tgw_b" {
  route_table_id         = aws_route_table.app_priv_rt_b.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app]
}

resource "aws_route" "app_db_to_tgw" {
  route_table_id         = aws_route_table.app_db_rt.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app]
}

resource "aws_route" "app_pub_to_tgw" {
  route_table_id         = aws_route_table.app_pub_rt.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.app]
}