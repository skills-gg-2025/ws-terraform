# Dev VPC
resource "aws_vpc" "dev_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev-vpc"
  }
}

# Prod VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "prod-vpc"
  }
}

# Internet Gateways
resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod-igw"
  }
}

# Dev Public Subnets
resource "aws_subnet" "dev_public_1" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "dev-public-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "dev_public_2" {
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "dev-public-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Dev Private Subnets
resource "aws_subnet" "dev_private_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.1.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                              = "dev-private-1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "dev_private_2" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.1.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = "dev-private-2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Prod Public Subnets
resource "aws_subnet" "prod_public_1" {
  vpc_id                  = aws_vpc.prod_vpc.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "prod-public-1"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "prod_public_2" {
  vpc_id                  = aws_vpc.prod_vpc.id
  cidr_block              = "10.2.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "prod-public-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Prod Private Subnets
resource "aws_subnet" "prod_private_1" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.2.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                              = "prod-private-1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "prod_private_2" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.2.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = "prod-private-2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateways
resource "aws_eip" "dev_nat_eip_1" {
  domain = "vpc"
  tags = {
    Name = "dev-nat-eip-1"
  }
}

resource "aws_eip" "dev_nat_eip_2" {
  domain = "vpc"
  tags = {
    Name = "dev-nat-eip-2"
  }
}

resource "aws_eip" "prod_nat_eip_1" {
  domain = "vpc"
  tags = {
    Name = "prod-nat-eip-1"
  }
}

resource "aws_eip" "prod_nat_eip_2" {
  domain = "vpc"
  tags = {
    Name = "prod-nat-eip-2"
  }
}

resource "aws_nat_gateway" "dev_nat_1" {
  allocation_id = aws_eip.dev_nat_eip_1.id
  subnet_id     = aws_subnet.dev_public_1.id

  tags = {
    Name = "dev-nat-1"
  }

  depends_on = [aws_internet_gateway.dev_igw]
}

resource "aws_nat_gateway" "dev_nat_2" {
  allocation_id = aws_eip.dev_nat_eip_2.id
  subnet_id     = aws_subnet.dev_public_2.id

  tags = {
    Name = "dev-nat-2"
  }

  depends_on = [aws_internet_gateway.dev_igw]
}

resource "aws_nat_gateway" "prod_nat_1" {
  allocation_id = aws_eip.prod_nat_eip_1.id
  subnet_id     = aws_subnet.prod_public_1.id

  tags = {
    Name = "prod-nat-1"
  }

  depends_on = [aws_internet_gateway.prod_igw]
}

resource "aws_nat_gateway" "prod_nat_2" {
  allocation_id = aws_eip.prod_nat_eip_2.id
  subnet_id     = aws_subnet.prod_public_2.id

  tags = {
    Name = "prod-nat-2"
  }

  depends_on = [aws_internet_gateway.prod_igw]
}

resource "aws_vpc_peering_connection" "dev_prod_peering" {
  peer_vpc_id = aws_vpc.prod_vpc.id
  vpc_id      = aws_vpc.dev_vpc.id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = {
    Name = "dev-prod-peering"
  }
}

# Route Tables
resource "aws_route_table" "dev_public_rt" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  route {
    cidr_block                = aws_vpc.prod_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "dev-public-rt"
  }
}

resource "aws_route_table" "dev_private_rt_1" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev_nat_1.id
  }

  route {
    cidr_block                = aws_vpc.prod_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "dev-private-rt-1"
  }
}

resource "aws_route_table" "dev_private_rt_2" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dev_nat_2.id
  }

  route {
    cidr_block                = aws_vpc.prod_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "dev-private-rt-2"
  }
}

resource "aws_route_table" "prod_public_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_igw.id
  }

  route {
    cidr_block                = aws_vpc.dev_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "prod-public-rt"
  }
}

resource "aws_route_table" "prod_private_rt_1" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod_nat_1.id
  }

  route {
    cidr_block                = aws_vpc.dev_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "prod-private-rt-1"
  }
}

resource "aws_route_table" "prod_private_rt_2" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod_nat_2.id
  }

  route {
    cidr_block                = aws_vpc.dev_vpc.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.dev_prod_peering.id
  }

  tags = {
    Name = "prod-private-rt-2"
  }
}

# Route Table Associations
resource "aws_route_table_association" "dev_public_1_rta" {
  subnet_id      = aws_subnet.dev_public_1.id
  route_table_id = aws_route_table.dev_public_rt.id
}

resource "aws_route_table_association" "dev_public_2_rta" {
  subnet_id      = aws_subnet.dev_public_2.id
  route_table_id = aws_route_table.dev_public_rt.id
}

resource "aws_route_table_association" "dev_private_1_rta" {
  subnet_id      = aws_subnet.dev_private_1.id
  route_table_id = aws_route_table.dev_private_rt_1.id
}

resource "aws_route_table_association" "dev_private_2_rta" {
  subnet_id      = aws_subnet.dev_private_2.id
  route_table_id = aws_route_table.dev_private_rt_2.id
}

resource "aws_route_table_association" "prod_public_1_rta" {
  subnet_id      = aws_subnet.prod_public_1.id
  route_table_id = aws_route_table.prod_public_rt.id
}

resource "aws_route_table_association" "prod_public_2_rta" {
  subnet_id      = aws_subnet.prod_public_2.id
  route_table_id = aws_route_table.prod_public_rt.id
}

resource "aws_route_table_association" "prod_private_1_rta" {
  subnet_id      = aws_subnet.prod_private_1.id
  route_table_id = aws_route_table.prod_private_rt_1.id
}

resource "aws_route_table_association" "prod_private_2_rta" {
  subnet_id      = aws_subnet.prod_private_2.id
  route_table_id = aws_route_table.prod_private_rt_2.id
}
