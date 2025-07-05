# Data source for Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Key Pair
resource "aws_key_pair" "ws_cicd_key_pair" {
  key_name   = "ws-cicd-key-pair"
  public_key = file("./src/ws-cicd-key-pair.pub")
}

# IAM Role for Bastion
resource "aws_iam_role" "ws_cicd_admin_role" {
  name = "ws-cicd-admin-role"

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
resource "aws_iam_role_policy_attachment" "ws_cicd_admin_policy" {
  role       = aws_iam_role.ws_cicd_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "ws_cicd_admin_profile" {
  name = "ws-cicd-admin-role"
  role = aws_iam_role.ws_cicd_admin_role.name
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.cicd_vpc.id

  ingress {
    from_port   = 1208
    to_port     = 1208
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

# Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  tags = {
    Name = "bastion-eip"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "ws_cicd_bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ws_cicd_key_pair.key_name
  subnet_id              = aws_subnet.cicd_public_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ws_cicd_admin_profile.name

  user_data = <<-EOF
    #!/bin/bash
    sed -i 's/#Port 22/Port 1208/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name = "ws-cicd-bastion"
  }
}

# Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.ws_cicd_bastion.id
  allocation_id = aws_eip.bastion_eip.id
}