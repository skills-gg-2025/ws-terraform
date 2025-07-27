# Data source for Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source for default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.available.names[0]
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Key pair
resource "aws_key_pair" "workflow_key_pair" {
  key_name   = "ws-workflow-key-pair"
  public_key = file("${path.module}/src/ws-workflow-key-pair.pub")
}

# IAM role for Bastion
resource "aws_iam_role" "workflow_admin_role" {
  name = "ws-workflow-admin-role"

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

# Attach AdministratorAccess policy
resource "aws_iam_role_policy_attachment" "workflow_admin_policy" {
  role       = aws_iam_role.workflow_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance profile
resource "aws_iam_instance_profile" "workflow_admin_profile" {
  name = "ws-workflow-admin-role"
  role = aws_iam_role.workflow_admin_role.name
}

# Security group for Bastion
resource "aws_security_group" "bastion_sg" {
  name_prefix = "ws-workflow-bastion-sg"
  vpc_id      = data.aws_vpc.default.id

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
}

# Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"

  tags = {
    Name = "ws-workflow-bastion-eip"
  }
}

# Bastion EC2 instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.workflow_key_pair.key_name
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.workflow_admin_profile.name

  tags = {
    Name = "ws-workflow-bastion"
  }
}

# Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}