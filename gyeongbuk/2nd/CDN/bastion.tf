# Read the public key file
locals {
  public_key = file("${path.module}/src/mrap-bastion-key.pub")
}

# Key pair for bastion
resource "aws_key_pair" "bastion" {
  provider   = aws.korea
  key_name   = "mrap-bastion-key"
  public_key = local.public_key

  tags = {
    Name = "mrap-bastion-key"
  }
}

# Security group for bastion
resource "aws_security_group" "bastion" {
  provider = aws.korea
  name     = "mrap-bastion-sg"
  vpc_id   = aws_default_vpc.default_kr.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mrap-bastion-sg"
  }
}

# IAM role for bastion
resource "aws_iam_role" "bastion" {
  provider = aws.korea
  name     = "mrap-bastion-role"

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
    Name = "mrap-bastion-role"
  }
}

# Attach AdministratorAccess policy to bastion role
resource "aws_iam_role_policy_attachment" "bastion_admin_access" {
  provider   = aws.korea
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.bastion.name
}

# IAM instance profile for bastion
resource "aws_iam_instance_profile" "bastion" {
  provider = aws.korea
  name     = "mrap-bastion-profile"
  role     = aws_iam_role.bastion.name
}

# Elastic IP for bastion
resource "aws_eip" "bastion" {
  provider = aws.korea
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = {
    Name = "mrap-bastion-eip"
  }
}

# Get Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
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

# Bastion EC2 instance
resource "aws_instance" "bastion" {
  provider                    = aws.korea
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.bastion.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  subnet_id                   = data.aws_subnets.default_kr.ids[0]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  tags = {
    Name = "mrap-bastion"
  }
}
