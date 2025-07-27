// IAM Role for Bastion with AdministratorAccess
resource "aws_iam_role" "ws_moni_admin_role" {
  name = "ws-moni-admin-role"

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

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.ws_moni_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "ws-moni-admin-role"
  role = aws_iam_role.ws_moni_admin_role.name
}

// Key Pair
resource "aws_key_pair" "ws_moni_key_pair" {
  key_name   = "ws-moni-key-pair"
  public_key = file("${path.module}/src/ws-moni-key-pair.pub")
}

// Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "ws-moni-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.moni_vpc.id

  ingress {
    from_port   = 1430
    to_port     = 1430
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Custom SSH port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ws-moni-bastion-sg"
  }
}

// Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"

  tags = {
    Name = "ws-moni-bastion-eip"
  }
}

// Bastion EC2 Instance
resource "aws_instance" "ws_moni_bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.moni_public_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.ws_moni_key_pair.key_name
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  user_data = <<-EOF
    #!/bin/bash
    # Configure SSH to use custom port
    sed -i 's/#Port 22/Port 1430/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name = "ws-moni-bastion"
  }
}

// Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.ws_moni_bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

// Data source for Amazon Linux 2023 AMI
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