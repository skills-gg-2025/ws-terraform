# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Key Pair
resource "aws_key_pair" "ws_analytics_key_pair" {
  key_name   = "ws-analytics-key-pair"
  public_key = file("./src/ws-analytics-key-pair.pub")
}

# IAM Role for Bastion
resource "aws_iam_role" "ws_analytics_admin_role" {
  name = "ws-analytics-admin-role"

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
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.ws_analytics_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "ws_analytics_admin_profile" {
  name = "ws-analytics-admin-role"
  role = aws_iam_role.ws_analytics_admin_role.name
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.data_vpc.id

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

# Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"
  tags = {
    Name = "bastion-eip"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "ws_analytics_bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ws_analytics_key_pair.key_name
  subnet_id              = aws_subnet.data_public_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ws_analytics_admin_profile.name

  tags = {
    Name = "ws-analytics-bastion"
  }
}

# Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.ws_analytics_bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

# IAM Role for App Instance (Fluent Bit logging)
resource "aws_iam_role" "ws_data_app_role" {
  name = "ws-data-app-role"

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

# IAM Policy for App Instance
resource "aws_iam_role_policy" "app_policy" {
  name = "app-policy"
  role = aws_iam_role.ws_data_app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile for App
resource "aws_iam_instance_profile" "ws_data_app_profile" {
  name = "ws-data-app-role"
  role = aws_iam_role.ws_data_app_role.name
}

# Security Group for App Instance
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group for app instance"
  vpc_id      = aws_vpc.data_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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

# App EC2 Instance
resource "aws_instance" "ws_data_app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.ws_analytics_key_pair.key_name
  subnet_id              = aws_subnet.data_private_a.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ws_data_app_profile.name

  provisioner "file" {
    source      = "${path.module}/src/app.py"
    destination = "/home/ec2-user/app.py"

    connection {
      type                = "ssh"
      user                = "ec2-user"
      private_key         = file("${path.module}/src/ws-analytics-key-pair")
      host                = self.private_ip
      bastion_host        = aws_eip.bastion_eip.public_ip
      bastion_user        = "ec2-user"
      bastion_private_key = file("${path.module}/src/ws-analytics-key-pair")
    }
  }

  user_data = file("${path.module}/src/user_data.sh")

  tags = {
    Name = "ws-data-app"
  }

  depends_on = [aws_eip_association.bastion_eip_assoc]
}