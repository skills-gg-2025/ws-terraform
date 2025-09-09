# Bastion Security Group
resource "aws_security_group" "bastion" {
  name   = "skills-bastion-sg"
  vpc_id = aws_vpc.consumer.id

  ingress {
    description = "SSH"
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
    Name = "skills-bastion-sg"
  }
}

# Bastion IAM Role
resource "aws_iam_role" "bastion" {
  name = "skills-bastion-role"

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

resource "aws_iam_role_policy_attachment" "bastion_admin" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "skills-bastion-profile"
  role = aws_iam_role.bastion.name
}

# Key Pair for Bastion
resource "aws_key_pair" "bastion" {
  key_name   = "skills-bastion-key"
  public_key = file("${path.module}/src/bastion_key.pub")
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name = "skills-bastion-eip"
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = aws_subnet.consumer_public_a.id
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    
    # Install curl and jq
    yum install -y curl jq
    
    # Configure AWS CLI region
    aws configure set region ap-southeast-1
  EOF

  tags = {
    Name = "skills-bastion"
  }
}

# Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# Data source for Amazon Linux 2023 AMI
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
