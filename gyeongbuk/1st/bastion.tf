# Data source for the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair for Bastion Host
resource "aws_key_pair" "bastion_key" {
  key_name   = "skills-bastion-key"
  public_key = file("${path.module}/src/skills-bastion-key.pub")

  tags = {
    Name = "skills-bastion-key"
  }
}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion_role" {
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

  tags = {
    Name = "skills-bastion-role"
  }
}

# Attach AdministratorAccess policy to the role
resource "aws_iam_role_policy_attachment" "bastion_admin_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Instance Profile for Bastion Host
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "skills-bastion-role"
  role = aws_iam_role.bastion_role.name

  tags = {
    Name = "skills-bastion-role"
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "skills-bastion-sg"
  description = "Security group for Skills Bastion Host"
  vpc_id      = aws_vpc.hub.id

  # SSH access on custom port 2025
  ingress {
    description = "SSH on port 2025"
    from_port   = 2025
    to_port     = 2025
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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

# Elastic IP for Bastion Host
resource "aws_eip" "bastion_eip" {
  domain = "vpc"

  tags = {
    Name = "skills-bastion-eip"
  }
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.bastion_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  subnet_id              = aws_subnet.hub_subnet_a.id
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  user_data              = file("${path.module}/src/user_data.sh")

  # Ensure the instance gets a public IP
  associate_public_ip_address = true

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "skills-bastion-root-volume"
    }
  }

  tags = {
    Name = "skills-bastion"
  }

  # Ensure the instance is fully initialized before associating EIP
  depends_on = [
    aws_internet_gateway.hub_igw,
    aws_route_table.hub_a_rt,
    aws_route_table_association.hub_subnet_a_rta
  ]
}

# Associate Elastic IP with Bastion Host
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}
