terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# 1. VPC 구성
resource "aws_vpc" "efs_vpc" {
  cidr_block           = "10.128.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "efs-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "efs_igw" {
  vpc_id = aws_vpc.efs_vpc.id

  tags = {
    Name = "efs-igw"
  }
}

# Public Subnets
resource "aws_subnet" "efs_pub_b" {
  vpc_id                  = aws_vpc.efs_vpc.id
  cidr_block              = "10.128.0.0/20"
  availability_zone       = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "efs-pub-b"
  }
}

resource "aws_subnet" "efs_pub_c" {
  vpc_id                  = aws_vpc.efs_vpc.id
  cidr_block              = "10.128.16.0/20"
  availability_zone       = "eu-west-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "efs-pub-c"
  }
}

# Private Subnets
resource "aws_subnet" "efs_app_b" {
  vpc_id            = aws_vpc.efs_vpc.id
  cidr_block        = "10.128.128.0/20"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "efs-app-b"
  }
}

resource "aws_subnet" "efs_app_c" {
  vpc_id            = aws_vpc.efs_vpc.id
  cidr_block        = "10.128.144.0/20"
  availability_zone = "eu-west-1c"

  tags = {
    Name = "efs-app-c"
  }
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "efs-nat-eip"
  }
}

resource "aws_nat_gateway" "efs_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.efs_pub_b.id

  tags = {
    Name = "efs-nat-gw"
  }

  depends_on = [aws_internet_gateway.efs_igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.efs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.efs_igw.id
  }

  tags = {
    Name = "efs-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.efs_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.efs_nat.id
  }

  tags = {
    Name = "efs-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.efs_pub_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.efs_pub_c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.efs_app_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.efs_app_c.id
  route_table_id = aws_route_table.private_rt.id
}

# 2. IAM Role 구성
resource "aws_iam_role" "wsi_ec2_efs_role" {
  name = "wsi-ec2-efs-role"

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
}

resource "aws_iam_role_policy_attachment" "efs_policy_attachment" {
  role       = aws_iam_role.wsi_ec2_efs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess"
}

# Bastion IAM Role
resource "aws_iam_role" "bastion_role" {
  name = "bastion-role"

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
}

resource "aws_iam_role_policy_attachment" "bastion_admin_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_iam_instance_profile" "wsi_ec2_efs_profile" {
  name = "wsi-ec2-efs-profile"
  role = aws_iam_role.wsi_ec2_efs_role.name
}

# 4. KMS Key
resource "aws_kms_key" "wsi_kms" {
  description = "KMS key for EFS encryption"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EFS access"
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow IAM role access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.wsi_ec2_efs_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "wsi_kms_alias" {
  name          = "alias/wsi-kms"
  target_key_id = aws_kms_key.wsi_kms.key_id
}

data "aws_caller_identity" "current" {}

# Security Groups
resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.efs_vpc.id

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
    Name = "bastion-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name_prefix = "app-sg"
  vpc_id      = aws_vpc.efs_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.efs_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "efs_sg" {
  name_prefix = "efs-sg"
  vpc_id      = aws_vpc.efs_vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "efs-sg"
  }
}

# Key Pair
resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key"
  public_key = file("bastion-key.pub")
}

# 3. EC2 Instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.8.20250721.2-kernel-6.1-x86_64"]
  }
}

# Bastion Host
resource "aws_network_interface" "bastion_eni" {
  subnet_id       = aws_subnet.efs_pub_b.id
  private_ips     = ["10.128.0.199"]
  security_groups = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "bastion-eni"
  }
}

resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  key_name            = aws_key_pair.bastion_key.key_name
  iam_instance_profile = aws_iam_instance_profile.bastion_profile.name

  network_interface {
    network_interface_id = aws_network_interface.bastion_eni.id
    device_index         = 0
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y sshpass
    
    # Configure SSH client to skip host key checking
    echo "Host *" >> /home/ec2-user/.ssh/config
    echo "    StrictHostKeyChecking no" >> /home/ec2-user/.ssh/config
    echo "    UserKnownHostsFile /dev/null" >> /home/ec2-user/.ssh/config
    chown ec2-user:ec2-user /home/ec2-user/.ssh/config
    chmod 600 /home/ec2-user/.ssh/config
  EOF
  )

  tags = {
    Name = "efs-bastion"
  }
}

resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  tags = {
    Name = "bastion-eip"
  }
}

resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

# App Instances
resource "aws_network_interface" "app1_eni" {
  subnet_id       = aws_subnet.efs_app_b.id
  private_ips     = ["10.128.128.199"]
  security_groups = [aws_security_group.app_sg.id]

  tags = {
    Name = "app1-eni"
  }
}

resource "aws_network_interface" "app2_eni" {
  subnet_id       = aws_subnet.efs_app_c.id
  private_ips     = ["10.128.144.199"]
  security_groups = [aws_security_group.app_sg.id]

  tags = {
    Name = "app2-eni"
  }
}

resource "aws_instance" "app1" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  key_name            = aws_key_pair.bastion_key.key_name
  iam_instance_profile = aws_iam_instance_profile.wsi_ec2_efs_profile.name

  network_interface {
    network_interface_id = aws_network_interface.app1_eni.id
    device_index         = 0
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-efs-utils sshpass
    
    # Set password for ec2-user
    echo "ec2-user:wsi101" | chpasswd
    
    # Enable password authentication
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Create mount point
    mkdir -p /mnt/efs
    
    # Mount EFS with access point
    echo "${aws_efs_file_system.wsi_efs.id}.efs.eu-west-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev,tls,iam,accesspoint=${aws_efs_access_point.wsi_efs_ap.id}" >> /etc/fstab
    
    # Wait for mount targets to be available
    sleep 30
    mount -a
    
    # Wait a bit more and retry if mount failed
    sleep 10
    if ! mountpoint -q /mnt/efs; then
        mount -a
    fi
    
    # Create hello-101.txt with temporary time change
    sleep 5
    if [ ! -f /mnt/efs/hello-101.txt ]; then
        # Disable NTP and set time to allowed range
        timedatectl set-ntp false
        timedatectl set-time "2025-09-22 12:00:00"
        # Create file
        echo "Hello from WorldSkills" > /mnt/efs/hello-101.txt
        chown ec2-user:ec2-user /mnt/efs/hello-101.txt
        # Re-enable NTP
        timedatectl set-ntp true
    fi
  EOF
  )

  tags = {
    Name    = "efs-app-1"
    AppRole = "wsi-app"
  }
}

resource "aws_instance" "app2" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  key_name            = aws_key_pair.bastion_key.key_name
  iam_instance_profile = aws_iam_instance_profile.wsi_ec2_efs_profile.name

  network_interface {
    network_interface_id = aws_network_interface.app2_eni.id
    device_index         = 0
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-efs-utils sshpass
    
    # Set password for ec2-user
    echo "ec2-user:wsi101" | chpasswd
    
    # Enable password authentication
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    # Create mount point
    mkdir -p /mnt/efs
    
    # Mount EFS with access point
    echo "${aws_efs_file_system.wsi_efs.id}.efs.eu-west-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev,tls,iam,accesspoint=${aws_efs_access_point.wsi_efs_ap.id}" >> /etc/fstab
    
    # Wait for mount targets to be available
    sleep 30
    mount -a
    
    # Wait a bit more and retry if mount failed
    sleep 10
    if ! mountpoint -q /mnt/efs; then
        mount -a
    fi
  EOF
  )

  tags = {
    Name    = "efs-app-2"
    AppRole = "wsi-app"
  }
}

# 5. EFS 구성
resource "aws_efs_file_system" "wsi_efs" {
  creation_token   = "wsi-efs-fs"
  encrypted        = true
  kms_key_id       = aws_kms_key.wsi_kms.arn
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100

  tags = {
    Name = "wsi-efs-fs"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "efs_mt_b" {
  file_system_id  = aws_efs_file_system.wsi_efs.id
  subnet_id       = aws_subnet.efs_app_b.id
  ip_address      = "10.128.128.111"
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mt_c" {
  file_system_id  = aws_efs_file_system.wsi_efs.id
  subnet_id       = aws_subnet.efs_app_c.id
  ip_address      = "10.128.144.111"
  security_groups = [aws_security_group.efs_sg.id]
}

# EFS File System Policy
resource "aws_efs_file_system_policy" "wsi_efs_policy" {
  file_system_id = aws_efs_file_system.wsi_efs.id
  bypass_policy_lockout_safety_check = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RequireSSL"
        Effect = "Allow"
        Principal = "*"
        Action = "*"
        Resource = aws_efs_file_system.wsi_efs.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      },
      {
        Sid    = "AllowAccessWithConditions"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.wsi_ec2_efs_role.arn
        }
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = aws_efs_file_system.wsi_efs.arn
        Condition = {
          DateGreaterThan = {
            "aws:CurrentTime" = "2025-09-20T03:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "2025-09-26T18:00:00Z"
          }
          StringEquals = {
            "aws:PrincipalTag/AppRole" = "wsi-app"
          }
          StringLike = {
            "elasticfilesystem:AccessPointArn" = "${aws_efs_access_point.wsi_efs_ap.arn}"
          }
        }
      }
    ]
  })
}

# EFS Access Point
resource "aws_efs_access_point" "wsi_efs_ap" {
  file_system_id = aws_efs_file_system.wsi_efs.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/app/wsi101"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "wsi-efs-ap"
  }
}