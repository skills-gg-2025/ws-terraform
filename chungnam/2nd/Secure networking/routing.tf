# NAT Gateway
resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "wsc2025-nat-eip-a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = {
    Name = "wsc2025-nat-eip-b"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.egress_public_a.id

  tags = {
    Name = "wsc2025-nat-gateway-a"
  }

  depends_on = [aws_internet_gateway.egress_igw]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.egress_public_b.id

  tags = {
    Name = "wsc2025-nat-gateway-b"
  }

  depends_on = [aws_internet_gateway.egress_igw]
}

# Route Tables
resource "aws_route_table" "egress_public" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.egress_igw.id
  }

  tags = {
    Name = "wsc2025-egress-public-rt"
  }
}

resource "aws_route_table" "egress_peering" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block = "172.16.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.app_to_egress.id
  }

  tags = {
    Name = "wsc2025-egress-peering-rt"
  }
}

resource "aws_route_table" "egress_firewall" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name = "wsc2025-egress-firewall-rt"
  }
}

resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    vpc_peering_connection_id = aws_vpc_peering_connection.app_to_egress.id
  }

  tags = {
    Name = "wsc2025-app-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "egress_public_a" {
  subnet_id      = aws_subnet.egress_public_a.id
  route_table_id = aws_route_table.egress_public.id
}

resource "aws_route_table_association" "egress_public_b" {
  subnet_id      = aws_subnet.egress_public_b.id
  route_table_id = aws_route_table.egress_public.id
}

resource "aws_route_table_association" "egress_peering_a" {
  subnet_id      = aws_subnet.egress_peering_a.id
  route_table_id = aws_route_table.egress_peering.id
}

resource "aws_route_table_association" "egress_peering_b" {
  subnet_id      = aws_subnet.egress_peering_b.id
  route_table_id = aws_route_table.egress_peering.id
}

resource "aws_route_table_association" "egress_firewall_a" {
  subnet_id      = aws_subnet.egress_firewall_a.id
  route_table_id = aws_route_table.egress_firewall.id
}

resource "aws_route_table_association" "egress_firewall_b" {
  subnet_id      = aws_subnet.egress_firewall_b.id
  route_table_id = aws_route_table.egress_firewall.id
}

resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.app_private.id
}

resource "aws_route_table_association" "app_private_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.app_private.id
}



# Route from peering subnet directly to NAT Gateway for internet access
resource "aws_route" "peering_to_nat" {
  route_table_id         = aws_route_table.egress_peering.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_a.id
}

# Route from public subnet back to App VPC through firewall
resource "aws_route" "public_to_app" {
  route_table_id         = aws_route_table.egress_public.id
  destination_cidr_block = "172.16.0.0/16"
  vpc_endpoint_id        = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  depends_on            = [aws_networkfirewall_firewall.main]
}

# Route from public subnet to peering subnets through firewall
resource "aws_route" "public_to_peering_a" {
  route_table_id         = aws_route_table.egress_public.id
  destination_cidr_block = "10.0.2.0/24"
  vpc_endpoint_id        = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  depends_on            = [aws_networkfirewall_firewall.main]
}

resource "aws_route" "public_to_peering_b" {
  route_table_id         = aws_route_table.egress_public.id
  destination_cidr_block = "10.0.3.0/24"
  vpc_endpoint_id        = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  depends_on            = [aws_networkfirewall_firewall.main]
}

