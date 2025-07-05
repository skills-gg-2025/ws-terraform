# CloudWatch Log Groups for VPC Flow Logs
resource "aws_cloudwatch_log_group" "hub_flow_logs" {
  name              = "/ws25/flow/hub"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "app_flow_logs" {
  name              = "/ws25/flow/app"
  retention_in_days = 7
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log_role" {
  name = "ws25-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "ws25-flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Hub VPC
resource "aws_vpc" "hub_vpc" {
  cidr_block           = "172.28.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "ws25-hub-vpc"
  }
}

# Application VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.200.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "ws25-app-vpc"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "hub_pub_a" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = "172.28.0.0/20"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "ws25-hub-pub-a"
  }
}

resource "aws_subnet" "hub_pub_c" {
  vpc_id                  = aws_vpc.hub_vpc.id
  cidr_block              = "172.28.16.0/20"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "ws25-hub-pub-c"
  }
}

# Application VPC Subnets
resource "aws_subnet" "app_pub_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.200.10.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "ws25-app-pub-a"
  }
}

resource "aws_subnet" "app_pub_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.200.11.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "ws25-app-pub-b"
  }
}

resource "aws_subnet" "app_pub_c" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.200.12.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = {
    Name = "ws25-app-pub-c"
  }
}

resource "aws_subnet" "app_pri_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.200.20.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "ws25-app-pri-a"
  }
}

resource "aws_subnet" "app_pri_b" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.200.21.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
    Name = "ws25-app-pri-b"
  }
}

resource "aws_subnet" "app_pri_c" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.200.22.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "ws25-app-pri-c"
  }
}

resource "aws_subnet" "app_db_a" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.200.30.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
    Name = "ws25-app-db-a"
  }
}

resource "aws_subnet" "app_db_c" {
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = "10.200.31.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
    Name = "ws25-app-db-c"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub_vpc.id
  tags = {
    Name = "ws25-hub-igw"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "ws25-app-igw"
  }
}

# NAT Gateways
resource "aws_eip" "app_nat_a" {
  domain = "vpc"
  tags = {
    Name = "ws25-app-ngw-a-eip"
  }
}

resource "aws_eip" "app_nat_c" {
  domain = "vpc"
  tags = {
    Name = "ws25-app-ngw-c-eip"
  }
}

resource "aws_nat_gateway" "app_nat_a" {
  allocation_id = aws_eip.app_nat_a.id
  subnet_id     = aws_subnet.app_pub_a.id
  tags = {
    Name = "ws25-app-ngw-a"
  }
}

resource "aws_nat_gateway" "app_nat_c" {
  allocation_id = aws_eip.app_nat_c.id
  subnet_id     = aws_subnet.app_pub_c.id
  tags = {
    Name = "ws25-app-ngw-c"
  }
}

# Route Tables
resource "aws_route_table" "hub_pub_rt" {
  vpc_id = aws_vpc.hub_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub_igw.id
  }
  route {
    cidr_block                = aws_vpc.app_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-hub-pub-rt"
  }
}

resource "aws_route_table" "app_pub_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-pub-rt"
  }
}

resource "aws_route_table" "app_pri_rt_a" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_a.id
  }
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-pri-rt-a"
  }
}

resource "aws_route_table" "app_pri_rt_b" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_c.id
  }
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-pri-rt-b"
  }
}

resource "aws_route_table" "app_pri_rt_c" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_c.id
  }
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-pri-rt-c"
  }
}

resource "aws_route_table" "app_db_rt_a" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-db-rt-a"
  }
}

resource "aws_route_table" "app_db_rt_c" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block                = aws_vpc.hub_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
  }
  tags = {
    Name = "ws25-app-db-rt-c"
  }
}

# Route Table Associations
resource "aws_route_table_association" "hub_pub_a" {
  subnet_id      = aws_subnet.hub_pub_a.id
  route_table_id = aws_route_table.hub_pub_rt.id
}

resource "aws_route_table_association" "hub_pub_c" {
  subnet_id      = aws_subnet.hub_pub_c.id
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

resource "aws_route_table_association" "app_pub_c" {
  subnet_id      = aws_subnet.app_pub_c.id
  route_table_id = aws_route_table.app_pub_rt.id
}

resource "aws_route_table_association" "app_pri_a" {
  subnet_id      = aws_subnet.app_pri_a.id
  route_table_id = aws_route_table.app_pri_rt_a.id
}

resource "aws_route_table_association" "app_pri_b" {
  subnet_id      = aws_subnet.app_pri_b.id
  route_table_id = aws_route_table.app_pri_rt_b.id
}

resource "aws_route_table_association" "app_pri_c" {
  subnet_id      = aws_subnet.app_pri_c.id
  route_table_id = aws_route_table.app_pri_rt_c.id
}

resource "aws_route_table_association" "app_db_a" {
  subnet_id      = aws_subnet.app_db_a.id
  route_table_id = aws_route_table.app_db_rt_a.id
}

resource "aws_route_table_association" "app_db_c" {
  subnet_id      = aws_subnet.app_db_c.id
  route_table_id = aws_route_table.app_db_rt_c.id
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "peering" {
  peer_vpc_id = aws_vpc.app_vpc.id
  vpc_id      = aws_vpc.hub_vpc.id
  auto_accept = true
  tags = {
    Name = "ws25-peering"
  }
}

# VPC Flow Logs
resource "aws_flow_log" "hub_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.hub_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.hub_vpc.id
}

resource "aws_flow_log" "app_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_cloudwatch_log_group.app_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.app_vpc.id
}

# VPC Endpoints for image downloads in private subnet
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.app_vpc.id
  service_name = "com.amazonaws.ap-northeast-2.s3"
  route_table_ids = [
    aws_route_table.app_pri_rt_a.id,
    aws_route_table.app_pri_rt_b.id,
    aws_route_table.app_pri_rt_c.id
  ]
  tags = {
    Name = "ws25-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.app_pri_a.id,
    aws_subnet.app_pri_b.id,
    aws_subnet.app_pri_c.id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  tags = {
    Name = "ws25-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.ap-northeast-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    aws_subnet.app_pri_a.id,
    aws_subnet.app_pri_b.id,
    aws_subnet.app_pri_c.id
  ]
  security_group_ids = [aws_security_group.vpc_endpoint.id]
  tags = {
    Name = "ws25-ecr-api-endpoint"
  }
}

resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "ws25-vpc-endpoint-sg"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app_vpc.cidr_block]
  }

  tags = {
    Name = "ws25-vpc-endpoint-sg"
  }
}