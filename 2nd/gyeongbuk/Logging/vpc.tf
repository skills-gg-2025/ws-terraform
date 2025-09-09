# VPC
resource "aws_vpc" "skills_log_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skills-log-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "skills_log_igw" {
  vpc_id = aws_vpc.skills_log_vpc.id

  tags = {
    Name = "skills-log-igw"
  }
}

# Private A Subnet
resource "aws_subnet" "skills_log_priv_a" {
  vpc_id            = aws_vpc.skills_log_vpc.id
  cidr_block        = "10.1.0.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "skills-log-priv-a"
  }
}

# Private B Subnet
resource "aws_subnet" "skills_log_priv_b" {
  vpc_id            = aws_vpc.skills_log_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "skills-log-priv-b"
  }
}

# Public A Subnet
resource "aws_subnet" "skills_log_pub_a" {
  vpc_id                  = aws_vpc.skills_log_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-log-pub-a"
  }
}

# Public B Subnet
resource "aws_subnet" "skills_log_pub_b" {
  vpc_id                  = aws_vpc.skills_log_vpc.id
  cidr_block              = "10.1.3.0/24"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "skills-log-pub-b"
  }
}

# Elastic IP for NAT Gateway A
resource "aws_eip" "skills_log_nat_eip_a" {
  domain = "vpc"

  tags = {
    Name = "skills-log-nat-eip-a"
  }
}

# Elastic IP for NAT Gateway B
resource "aws_eip" "skills_log_nat_eip_b" {
  domain = "vpc"

  tags = {
    Name = "skills-log-nat-eip-b"
  }
}

# NAT Gateway A
resource "aws_nat_gateway" "skills_log_nat_a" {
  allocation_id = aws_eip.skills_log_nat_eip_a.id
  subnet_id     = aws_subnet.skills_log_pub_a.id

  tags = {
    Name = "skills-log-nat-a"
  }

  depends_on = [aws_internet_gateway.skills_log_igw]
}

# NAT Gateway B
resource "aws_nat_gateway" "skills_log_nat_b" {
  allocation_id = aws_eip.skills_log_nat_eip_b.id
  subnet_id     = aws_subnet.skills_log_pub_b.id

  tags = {
    Name = "skills-log-nat-b"
  }

  depends_on = [aws_internet_gateway.skills_log_igw]
}

# Public Route Table
resource "aws_route_table" "skills_log_pub_rt" {
  vpc_id = aws_vpc.skills_log_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.skills_log_igw.id
  }

  tags = {
    Name = "skills-log-pub-rt"
  }
}

# Private Route Table A
resource "aws_route_table" "skills_log_priv_rt_a" {
  vpc_id = aws_vpc.skills_log_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.skills_log_nat_a.id
  }

  tags = {
    Name = "skills-log-priv-rt-a"
  }
}

# Private Route Table B
resource "aws_route_table" "skills_log_priv_rt_b" {
  vpc_id = aws_vpc.skills_log_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.skills_log_nat_b.id
  }

  tags = {
    Name = "skills-log-priv-rt-b"
  }
}

# Route Table Associations
resource "aws_route_table_association" "skills_log_pub_a_association" {
  subnet_id      = aws_subnet.skills_log_pub_a.id
  route_table_id = aws_route_table.skills_log_pub_rt.id
}

resource "aws_route_table_association" "skills_log_pub_b_association" {
  subnet_id      = aws_subnet.skills_log_pub_b.id
  route_table_id = aws_route_table.skills_log_pub_rt.id
}

resource "aws_route_table_association" "skills_log_priv_a_association" {
  subnet_id      = aws_subnet.skills_log_priv_a.id
  route_table_id = aws_route_table.skills_log_priv_rt_a.id
}

resource "aws_route_table_association" "skills_log_priv_b_association" {
  subnet_id      = aws_subnet.skills_log_priv_b.id
  route_table_id = aws_route_table.skills_log_priv_rt_b.id
}
