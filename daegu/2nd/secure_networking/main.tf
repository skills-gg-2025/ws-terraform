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
  region = "ap-northeast-2"
}

resource "aws_vpc" "dns_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dns-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dns_vpc.id

  tags = {
    Name = "dns-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dns_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "dns-public-subnet-c"
  }
}

resource "aws_subnet" "firewall_subnet" {
  vpc_id            = aws_vpc.dns_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "dns-firewall-subnet-c"
  }
}

resource "aws_networkfirewall_rule_group" "domain_block_rule_group" {
  capacity = 100
  name     = "domain-block-rule-group"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<-EOF
        drop http any any -> any any (content:"example.com"; sid:1;)
        drop tls any any -> any any (tls.sni; content:"example.com"; sid:2;)
      EOF
    }
  }

  tags = {
    Name = "domain-block-rule-group"
  }
}

resource "aws_networkfirewall_rule_group" "traffic_allow_rule_group" {
  capacity = 100
  name     = "traffic-allow-rule-group"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<-EOF
        pass tcp $EXTERNAL_NET any -> $HOME_NET 22 (sid:3;)
        pass tcp $HOME_NET any -> $EXTERNAL_NET 443 (sid:4;)
        pass udp $HOME_NET any -> $EXTERNAL_NET 53 (sid:5;)
        drop ip any any -> any any (sid:6;)
      EOF
    }
  }

  tags = {
    Name = "traffic-allow-rule-group"
  }
}

resource "aws_networkfirewall_firewall_policy" "dns_policy" {
  name = "dns-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.domain_block_rule_group.arn
    }
    
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.traffic_allow_rule_group.arn
    }
  }

  tags = {
    Name = "dns-firewall-policy"
  }
}

resource "aws_networkfirewall_firewall" "dns_firewall" {
  name                = "dns-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.dns_policy.arn
  vpc_id              = aws_vpc.dns_vpc.id

  subnet_mapping {
    subnet_id = aws_subnet.firewall_subnet.id
  }

  tags = {
    Name = "dns-firewall"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.dns_vpc.id

  tags = {
    Name = "dns-public-rt"
  }
}

resource "aws_route" "public_to_firewall" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = tolist(aws_networkfirewall_firewall.dns_firewall.firewall_status[0].sync_states)[0].attachment[0].endpoint_id
  
  depends_on = [aws_networkfirewall_firewall.dns_firewall]
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "firewall_rt" {
  vpc_id = aws_vpc.dns_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "dns-firewall-rt"
  }
}

resource "aws_route_table_association" "firewall_rta" {
  subnet_id      = aws_subnet.firewall_subnet.id
  route_table_id = aws_route_table.firewall_rt.id
}

resource "aws_route_table" "igw_rt" {
  vpc_id = aws_vpc.dns_vpc.id

  tags = {
    Name = "dns-igw-rt"
  }
}

resource "aws_route" "igw_to_firewall" {
  route_table_id         = aws_route_table.igw_rt.id
  destination_cidr_block = "10.0.1.0/24"
  vpc_endpoint_id        = tolist(aws_networkfirewall_firewall.dns_firewall.firewall_status[0].sync_states)[0].attachment[0].endpoint_id
  
  depends_on = [aws_networkfirewall_firewall.dns_firewall]
}

resource "aws_route_table_association" "igw_rta" {
  gateway_id     = aws_internet_gateway.igw.id
  route_table_id = aws_route_table.igw_rt.id
}

resource "aws_iam_role" "ec2_role" {
  name = "dns-bastion-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "dns-bastion-ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_admin_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dns-bastion-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "dns-bastion-ec2-profile"
  }
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "dns-bastion-sg"
  vpc_id      = aws_vpc.dns_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dns-bastion-sg"
  }
}

resource "tls_private_key" "dns_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "dns_key" {
  key_name   = "dns-bastion-key"
  public_key = tls_private_key.dns_key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.dns_key.private_key_pem
  filename = "dns-bastion-key.pem"
  file_permission = "0600"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.dns_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y bind-utils curl
  EOF

  tags = {
    Name = "dns-bastion-ec2"
  }
}