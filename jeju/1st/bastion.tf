# Use direct resource reference for hub-public-a subnet

# Security Group for Bastion
resource "aws_security_group" "hub_bastion_sg" {
  name        = "hub-bastion-sg"
  description = "Security group for hub bastion"
  vpc_id      = aws_vpc.hub_vpc.id

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
    Name = "hub-bastion-sg"
  }
}

# IAM Role for Bastion
resource "aws_iam_role" "hub_bastion_role" {
  name = "hub-bastion-role"

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
    Name = "hub-bastion-role"
  }
}

# Attach AdministratorAccess policy to Bastion role
resource "aws_iam_role_policy_attachment" "hub_bastion_admin_policy" {
  role       = aws_iam_role.hub_bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "hub_bastion_profile" {
  name = "hub-bastion-profile"
  role = aws_iam_role.hub_bastion_role.name

  tags = {
    Name = "hub-bastion-profile"
  }
}

# Key Pair for Bastion
resource "aws_key_pair" "hub_bastion_key" {
  key_name   = "hub-bastion-key"
  public_key = file("./src/hub-bastion-key.pem.pub")

  tags = {
    Name = "hub-bastion-key"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "hub_bastion" {
  ami                    = "ami-0ae2c887094315bed"
  instance_type          = "t3.micro"
  key_name              = aws_key_pair.hub_bastion_key.key_name
  subnet_id             = aws_subnet.hub_public_a.id
  vpc_security_group_ids = [aws_security_group.hub_bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.hub_bastion_profile.name

  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y awscli jq curl
    
    # Install kubectl
    curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2024-09-12/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
    echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
    
    # Configure AWS CLI region
    aws configure set default.region ap-northeast-2
  EOF
  )

  depends_on = [
    aws_internet_gateway.hub_igw,
    aws_route_table_association.hub_public_a
  ]

  tags = {
    Name = "hub-bastion"
  }
}