terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Hub VPC
resource "aws_vpc" "hub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gj2025-hub-vpc"
  }
}

# App VPC
resource "aws_vpc" "app" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "gj2025-app-vpc"
  }
}

# Internet Gateway for Hub VPC
resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "gj2025-hub-igw"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "hub_public_a" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "gj2025-hub-public-subnet-a"
  }
}

resource "aws_subnet" "hub_public_b" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "gj2025-hub-public-subnet-b"
  }
}

resource "aws_subnet" "hub_private_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gj2025-hub-private-subnet-a"
  }
}

resource "aws_subnet" "hub_private_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "gj2025-hub-private-subnet-b"
  }
}

resource "aws_subnet" "hub_firewall" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gj2025-hub-firewall-subnet"
  }
}

# App VPC Subnets
resource "aws_subnet" "app_private_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gj2025-app-private-subnet-a"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "app_private_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "gj2025-app-private-subnet-b"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "app_data_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "gj2025-app-data-subnet-a"
  }
}

resource "aws_subnet" "app_data_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "gj2025-app-data-subnet-b"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "gj2025-hub-ngw-eip"
  }
}

resource "aws_nat_gateway" "hub" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.hub_public_a.id

  tags = {
    Name = "gj2025-hub-ngw"
  }

  depends_on = [aws_internet_gateway.hub]
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description = "Transit Gateway for hub-spoke architecture"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "gj2025-tgw"
  }
}

# Transit Gateway VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids                                      = [aws_subnet.hub_private_a.id, aws_subnet.hub_private_b.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.hub.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "gj2025-hub-tgw-attach"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "app" {
  subnet_ids                                      = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.main.id
  vpc_id                                          = aws_vpc.app.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "gj2025-app-tgw-attach"
  }
}

# Transit Gateway Route Tables
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "gj2025-hub-tgw-rtb"
  }
}

resource "aws_ec2_transit_gateway_route_table" "app" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id

  tags = {
    Name = "gj2025-app-tgw-rtb"
  }
}

# Transit Gateway Route Table Associations
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_association" "app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# Transit Gateway Routes
resource "aws_ec2_transit_gateway_route" "hub_to_app" {
  destination_cidr_block         = "192.168.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route" "app_to_hub" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.app.id
}

# Transit Gateway Route Table Propagation
resource "aws_ec2_transit_gateway_route_table_propagation" "app_to_hub" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Network Firewall Rule Group
resource "aws_networkfirewall_rule_group" "main" {
  capacity = 100
  name     = "gj2025-firewall-rule"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
drop tls any any -> any any (ssl_state:client_hello; tls.sni; content:"ifconfig.io"; startswith; nocase; endswith; msg:"matching TLS denylisted FQDNs"; flow:to_server, established; sid:1; rev:1;)
drop http any any -> any any (http.host; content:"ifconfig.io"; startswith; endswith; msg:"matching HTTP denylisted FQDNs"; flow:to_server, established; sid:2; rev:1;)
EOF
    }
  }

  tags = {
    Name = "gj2025-firewall-rule"
  }
}

# Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "gj2025-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.main.arn
    }
  }

  tags = {
    Name = "gj2025-firewall-policy"
  }
}

# CloudWatch Log Group for Network Firewall
resource "aws_cloudwatch_log_group" "firewall" {
  name              = "/gj2025/firewall"
  retention_in_days = 7

  tags = {
    Name = "gj2025-firewall-logs"
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = "gj2025-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = aws_vpc.hub.id

  subnet_mapping {
    subnet_id = aws_subnet.hub_firewall.id
  }

  tags = {
    Name = "gj2025-firewall"
  }
}

# Network Firewall Logging Configuration
resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}

# Route Tables
resource "aws_route_table" "hub_public" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }

  route {
    cidr_block      = "192.168.0.0/16"
    vpc_endpoint_id = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  }

  tags = {
    Name = "gj2025-hub-public-rtb"
  }
}

resource "aws_route_table" "hub_private_a" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  }

  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-hub-private-rtb-a"
  }
}

resource "aws_route_table" "hub_private_b" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = [for k, v in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : v.attachment[0].endpoint_id][0]
  }

  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-hub-private-rtb-b"
  }
}

resource "aws_route_table" "hub_firewall" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.hub.id
  }

  route {
    cidr_block         = "192.168.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-hub-firewall-rtb"
  }
}

resource "aws_route_table" "app_private_a" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-app-private-rtb-a"
  }
}

resource "aws_route_table" "app_private_b" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-app-private-rtb-b"
  }
}

resource "aws_route_table" "app_data_a" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block         = "10.0.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-app-data-rtb-a"
  }
}

resource "aws_route_table" "app_data_b" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block         = "10.0.0.0/16"
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "gj2025-app-data-rtb-b"
  }
}

# Route Table Associations
resource "aws_route_table_association" "hub_public_a" {
  subnet_id      = aws_subnet.hub_public_a.id
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_route_table_association" "hub_public_b" {
  subnet_id      = aws_subnet.hub_public_b.id
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_route_table_association" "hub_private_a" {
  subnet_id      = aws_subnet.hub_private_a.id
  route_table_id = aws_route_table.hub_private_a.id
}

resource "aws_route_table_association" "hub_private_b" {
  subnet_id      = aws_subnet.hub_private_b.id
  route_table_id = aws_route_table.hub_private_b.id
}

resource "aws_route_table_association" "hub_firewall" {
  subnet_id      = aws_subnet.hub_firewall.id
  route_table_id = aws_route_table.hub_firewall.id
}

resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.app_private_a.id
}

resource "aws_route_table_association" "app_private_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.app_private_b.id
}

resource "aws_route_table_association" "app_data_a" {
  subnet_id      = aws_subnet.app_data_a.id
  route_table_id = aws_route_table.app_data_a.id
}

resource "aws_route_table_association" "app_data_b" {
  subnet_id      = aws_subnet.app_data_b.id
  route_table_id = aws_route_table.app_data_b.id
}

