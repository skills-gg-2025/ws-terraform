# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Hub VPC
resource "aws_vpc" "hub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skills-hub-vpc"
  }
}

# Hub VPC Subnets
resource "aws_subnet" "hub_subnet_a" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-hub-subnet-a"
  }
}

resource "aws_subnet" "hub_subnet_b" {
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-hub-subnet-b"
  }
}

resource "aws_subnet" "inspect_subnet_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "skills-inspect-subnet-a"
  }
}

resource "aws_subnet" "inspect_subnet_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "skills-inspect-subnet-b"
  }
}

# App VPC
resource "aws_vpc" "app" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skills-app-vpc"
  }
}

# App VPC Subnets
resource "aws_subnet" "app_subnet_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.0.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "skills-app-subnet-a"
  }
}

resource "aws_subnet" "app_subnet_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "skills-app-subnet-b"
  }
}

resource "aws_subnet" "workload_subnet_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "skills-workload-subnet-a"
  }
}

resource "aws_subnet" "workload_subnet_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.3.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "skills-workload-subnet-b"
  }
}

resource "aws_subnet" "db_subnet_a" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.4.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "skills-db-subnet-a"
  }
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id            = aws_vpc.app.id
  cidr_block        = "192.168.5.0/24"
  availability_zone = "ap-northeast-2b"

  tags = {
    Name = "skills-db-subnet-b"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "skills-hub-igw"
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "skills-app-igw"
  }
}

# NAT Gateways
resource "aws_eip" "hub_nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "skills-hub-nat-eip-a"
  }
}

resource "aws_eip" "hub_nat_eip_b" {
  domain = "vpc"

  tags = {
    Name = "skills-hub-nat-eip-b"
  }
}

resource "aws_nat_gateway" "hub_nat_a" {
  allocation_id = aws_eip.hub_nat_eip_a.id
  subnet_id     = aws_subnet.hub_subnet_a.id

  tags = {
    Name = "skills-hub-nat-a"
  }

  depends_on = [aws_internet_gateway.hub_igw]
}

resource "aws_nat_gateway" "hub_nat_b" {
  allocation_id = aws_eip.hub_nat_eip_b.id
  subnet_id     = aws_subnet.hub_subnet_b.id

  tags = {
    Name = "skills-hub-nat-b"
  }

  depends_on = [aws_internet_gateway.hub_igw]
}

# App VPC NAT Gateways
resource "aws_eip" "app_nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "skills-app-nat-eip-a"
  }
}

resource "aws_eip" "app_nat_eip_b" {
  domain = "vpc"

  tags = {
    Name = "skills-app-nat-eip-b"
  }
}

resource "aws_nat_gateway" "app_nat_a" {
  allocation_id = aws_eip.app_nat_eip_a.id
  subnet_id     = aws_subnet.app_subnet_a.id

  tags = {
    Name = "skills-app-nat-a"
  }

  depends_on = [aws_internet_gateway.app_igw]
}

resource "aws_nat_gateway" "app_nat_b" {
  allocation_id = aws_eip.app_nat_eip_b.id
  subnet_id     = aws_subnet.app_subnet_b.id

  tags = {
    Name = "skills-app-nat-b"
  }

  depends_on = [aws_internet_gateway.app_igw]
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "skills_peering" {
  peer_vpc_id = aws_vpc.app.id
  vpc_id      = aws_vpc.hub.id
  auto_accept = true

  tags = {
    Name = "skills-peering"
  }
}

# VPC Endpoints for ECR and S3 in App VPC
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.app.id
  service_name        = "com.amazonaws.ap-northeast-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "skills-ecr-dkr-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.app.id
  service_name = "com.amazonaws.ap-northeast-2.s3"

  tags = {
    Name = "skills-s3-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "skills-vpc-endpoint-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.app.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-vpc-endpoint-sg"
  }
}
