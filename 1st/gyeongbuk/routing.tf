# Hub VPC Internet Gateway Route Table (IGW -> Network Firewall)
resource "aws_route_table" "hub_igw_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block      = "10.0.0.0/24"
    vpc_endpoint_id = tolist(aws_networkfirewall_firewall.skills_firewall.firewall_status[0].sync_states)[0].attachment[0].endpoint_id
  }

  route {
    cidr_block      = "10.0.1.0/24"
    vpc_endpoint_id = tolist(aws_networkfirewall_firewall.skills_firewall.firewall_status[0].sync_states)[1].attachment[0].endpoint_id
  }

  tags = {
    Name = "skills-hub-igw-rtb"
  }
}

# Hub VPC Route Tables (Subnet A -> Network Firewall A)
resource "aws_route_table" "hub_a_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = tolist(aws_networkfirewall_firewall.skills_firewall.firewall_status[0].sync_states)[0].attachment[0].endpoint_id
  }

  route {
    cidr_block                = "192.168.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-hub-a-rtb"
  }
}

# Hub VPC Route Tables (Subnet B -> Network Firewall B)
resource "aws_route_table" "hub_b_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = tolist(aws_networkfirewall_firewall.skills_firewall.firewall_status[0].sync_states)[1].attachment[0].endpoint_id
  }

  route {
    cidr_block                = "192.168.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-hub-b-rtb"
  }
}

# Inspection Subnet Route Tables (Network Firewall -> IGW)
resource "aws_route_table" "inspect_a_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }

  tags = {
    Name = "skills-inspect-a-rtb"
  }
}

resource "aws_route_table" "inspect_b_rt" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }

  tags = {
    Name = "skills-inspect-b-rtb"
  }
}

# Hub VPC Route Table Associations
resource "aws_route_table_association" "hub_subnet_a_rta" {
  subnet_id      = aws_subnet.hub_subnet_a.id
  route_table_id = aws_route_table.hub_a_rt.id
}

resource "aws_route_table_association" "hub_subnet_b_rta" {
  subnet_id      = aws_subnet.hub_subnet_b.id
  route_table_id = aws_route_table.hub_b_rt.id
}

resource "aws_route_table_association" "inspect_subnet_a_rta" {
  subnet_id      = aws_subnet.inspect_subnet_a.id
  route_table_id = aws_route_table.inspect_a_rt.id
}

resource "aws_route_table_association" "inspect_subnet_b_rta" {
  subnet_id      = aws_subnet.inspect_subnet_b.id
  route_table_id = aws_route_table.inspect_b_rt.id
}

# IGW Route Table Association
resource "aws_route_table_association" "hub_igw_rta" {
  gateway_id     = aws_internet_gateway.hub_igw.id
  route_table_id = aws_route_table.hub_igw_rt.id
}

# App VPC Route Tables
resource "aws_route_table" "app_rt" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-app-rtb"
  }
}

resource "aws_route_table" "app_workload_rt_a" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_a.id
  }

  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-workload-a-rtb"
  }
}

resource "aws_route_table" "app_workload_rt_b" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_b.id
  }

  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-workload-b-rtb"
  }
}

resource "aws_route_table" "app_db_rt" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block                = "10.0.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.skills_peering.id
  }

  tags = {
    Name = "skills-db-rtb"
  }
}

# App VPC Route Table Associations
resource "aws_route_table_association" "app_subnet_a_rta" {
  subnet_id      = aws_subnet.app_subnet_a.id
  route_table_id = aws_route_table.app_rt.id
}

resource "aws_route_table_association" "app_subnet_b_rta" {
  subnet_id      = aws_subnet.app_subnet_b.id
  route_table_id = aws_route_table.app_rt.id
}

resource "aws_route_table_association" "workload_subnet_a_rta" {
  subnet_id      = aws_subnet.workload_subnet_a.id
  route_table_id = aws_route_table.app_workload_rt_a.id
}

resource "aws_route_table_association" "workload_subnet_b_rta" {
  subnet_id      = aws_subnet.workload_subnet_b.id
  route_table_id = aws_route_table.app_workload_rt_b.id
}

resource "aws_route_table_association" "db_subnet_a_rta" {
  subnet_id      = aws_subnet.db_subnet_a.id
  route_table_id = aws_route_table.app_db_rt.id
}

resource "aws_route_table_association" "db_subnet_b_rta" {
  subnet_id      = aws_subnet.db_subnet_b.id
  route_table_id = aws_route_table.app_db_rt.id
}

# VPC Endpoint Route Table Association for S3
resource "aws_vpc_endpoint_route_table_association" "s3_workload_a" {
  route_table_id  = aws_route_table.app_workload_rt_a.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_workload_b" {
  route_table_id  = aws_route_table.app_workload_rt_b.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
