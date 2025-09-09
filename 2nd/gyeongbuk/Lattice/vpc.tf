# Consumer VPC
resource "aws_vpc" "consumer" {
  cidr_block           = "172.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skills-consumer-vpc"
  }
}

# Consumer Internet Gateway
resource "aws_internet_gateway" "consumer" {
  vpc_id = aws_vpc.consumer.id

  tags = {
    Name = "skills-consumer-igw"
  }
}

# Consumer Public Subnets
resource "aws_subnet" "consumer_public_a" {
  vpc_id                  = aws_vpc.consumer.id
  cidr_block              = "172.168.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-consumer-public-subnet-a"
  }
}

resource "aws_subnet" "consumer_public_c" {
  vpc_id                  = aws_vpc.consumer.id
  cidr_block              = "172.168.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-consumer-public-subnet-c"
  }
}

# Consumer Private Subnets
resource "aws_subnet" "consumer_private_a" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = "172.168.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "skills-consumer-workload-subnet-a"
  }
}

resource "aws_subnet" "consumer_private_c" {
  vpc_id            = aws_vpc.consumer.id
  cidr_block        = "172.168.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "skills-consumer-workload-subnet-c"
  }
}

# Consumer Elastic IPs for NAT Gateways
resource "aws_eip" "consumer_nat_a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.consumer]

  tags = {
    Name = "skills-consumer-nat-a-eip"
  }
}

resource "aws_eip" "consumer_nat_c" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.consumer]

  tags = {
    Name = "skills-consumer-nat-c-eip"
  }
}

# Consumer NAT Gateways
resource "aws_nat_gateway" "consumer_nat_a" {
  allocation_id = aws_eip.consumer_nat_a.id
  subnet_id     = aws_subnet.consumer_public_a.id

  tags = {
    Name = "skills-consumer-nat-a"
  }

  depends_on = [aws_internet_gateway.consumer]
}

resource "aws_nat_gateway" "consumer_nat_c" {
  allocation_id = aws_eip.consumer_nat_c.id
  subnet_id     = aws_subnet.consumer_public_c.id

  tags = {
    Name = "skills-consumer-nat-c"
  }

  depends_on = [aws_internet_gateway.consumer]
}

# Consumer Route Tables
resource "aws_route_table" "consumer_public" {
  vpc_id = aws_vpc.consumer.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.consumer.id
  }

  tags = {
    Name = "skills-consumer-public-rt"
  }
}

resource "aws_route_table" "consumer_private_a" {
  vpc_id = aws_vpc.consumer.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.consumer_nat_a.id
  }

  tags = {
    Name = "skills-consumer-workload-rt-a"
  }
}

resource "aws_route_table" "consumer_private_c" {
  vpc_id = aws_vpc.consumer.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.consumer_nat_c.id
  }

  tags = {
    Name = "skills-consumer-workload-rt-c"
  }
}

# Consumer Route Table Associations
resource "aws_route_table_association" "consumer_public_a" {
  subnet_id      = aws_subnet.consumer_public_a.id
  route_table_id = aws_route_table.consumer_public.id
}

resource "aws_route_table_association" "consumer_public_c" {
  subnet_id      = aws_subnet.consumer_public_c.id
  route_table_id = aws_route_table.consumer_public.id
}

resource "aws_route_table_association" "consumer_private_a" {
  subnet_id      = aws_subnet.consumer_private_a.id
  route_table_id = aws_route_table.consumer_private_a.id
}

resource "aws_route_table_association" "consumer_private_c" {
  subnet_id      = aws_subnet.consumer_private_c.id
  route_table_id = aws_route_table.consumer_private_c.id
}

# Service VPC
resource "aws_vpc" "service" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skills-service-vpc"
  }
}

# Service Internet Gateway
resource "aws_internet_gateway" "service" {
  vpc_id = aws_vpc.service.id

  tags = {
    Name = "skills-service-igw"
  }
}

# Service Public Subnets
resource "aws_subnet" "service_public_a" {
  vpc_id                  = aws_vpc.service.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-service-public-subnet-a"
  }
}

resource "aws_subnet" "service_public_c" {
  vpc_id                  = aws_vpc.service.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-service-public-subnet-c"
  }
}

# Service Private Subnets
resource "aws_subnet" "service_private_a" {
  vpc_id            = aws_vpc.service.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "skills-service-workload-subnet-a"
  }
}

resource "aws_subnet" "service_private_c" {
  vpc_id            = aws_vpc.service.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "skills-service-workload-subnet-c"
  }
}

# Service Elastic IPs for NAT Gateways
resource "aws_eip" "service_nat_a" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.service]

  tags = {
    Name = "skills-service-nat-a-eip"
  }
}

resource "aws_eip" "service_nat_c" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.service]

  tags = {
    Name = "skills-service-nat-c-eip"
  }
}

# Service NAT Gateways
resource "aws_nat_gateway" "service_nat_a" {
  allocation_id = aws_eip.service_nat_a.id
  subnet_id     = aws_subnet.service_public_a.id

  tags = {
    Name = "skills-service-nat-a"
  }

  depends_on = [aws_internet_gateway.service]
}

resource "aws_nat_gateway" "service_nat_c" {
  allocation_id = aws_eip.service_nat_c.id
  subnet_id     = aws_subnet.service_public_c.id

  tags = {
    Name = "skills-service-nat-c"
  }

  depends_on = [aws_internet_gateway.service]
}

# Service Route Tables
resource "aws_route_table" "service_public" {
  vpc_id = aws_vpc.service.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.service.id
  }

  tags = {
    Name = "skills-service-public-rt"
  }
}

resource "aws_route_table" "service_private_a" {
  vpc_id = aws_vpc.service.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.service_nat_a.id
  }

  tags = {
    Name = "skills-service-workload-rt-a"
  }
}

resource "aws_route_table" "service_private_c" {
  vpc_id = aws_vpc.service.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.service_nat_c.id
  }

  tags = {
    Name = "skills-service-workload-rt-c"
  }
}

# Service Route Table Associations
resource "aws_route_table_association" "service_public_a" {
  subnet_id      = aws_subnet.service_public_a.id
  route_table_id = aws_route_table.service_public.id
}

resource "aws_route_table_association" "service_public_c" {
  subnet_id      = aws_subnet.service_public_c.id
  route_table_id = aws_route_table.service_public.id
}

resource "aws_route_table_association" "service_private_a" {
  subnet_id      = aws_subnet.service_private_a.id
  route_table_id = aws_route_table.service_private_a.id
}

resource "aws_route_table_association" "service_private_c" {
  subnet_id      = aws_subnet.service_private_c.id
  route_table_id = aws_route_table.service_private_c.id
}
