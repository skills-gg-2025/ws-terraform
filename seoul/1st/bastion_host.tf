# Data source for Amazon Linux 2023 AMI
# Using specified AMI ID
locals {
  bastion_ami = "ami-0ae2c887094315bed"
}

# Key Pair
resource "aws_key_pair" "wsk_bastion_key" {
  key_name   = "wsk-bastion-key"
  public_key = file("wsk-bastion-key.pem.pub")
}

# IAM Role for Bastion Host
resource "aws_iam_role" "wsk_bastion_profile" {
  name = "wsk-bastion-profile"

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

# Attach AdministratorAccess policy to the role
resource "aws_iam_role_policy_attachment" "wsk_bastion_admin_policy" {
  role       = aws_iam_role.wsk_bastion_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "wsk_bastion_profile" {
  name = "wsk-bastion-profile"
  role = aws_iam_role.wsk_bastion_profile.name
}

# Security Group for Bastion Host
resource "aws_security_group" "wsk_bastion_sg" {
  name        = "wsk-bastion-sg"
  description = "wsk-bastion-sg"
  vpc_id      = aws_vpc.wsk_hub.id

  ingress {
    from_port   = 2202
    to_port     = 2202
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.88.0.0/16"]
  }

  tags = {
    Name = "wsk-bastion-sg"
  }
}

# Network Interface for fixed IP
resource "aws_network_interface" "wsk_bastion_eni" {
  subnet_id       = aws_subnet.wsk_hub_pub_a.id
  private_ips     = ["10.76.10.100"]
  security_groups = [aws_security_group.wsk_bastion_sg.id]

  tags = {
    Name = "wsk-bastion-eni"
  }
}

# Elastic IP for Bastion Host
resource "aws_eip" "wsk_bastion_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.wsk_bastion_eni.id
  depends_on        = [aws_internet_gateway.wsk_hub_igw]
}

# Bastion Host EC2 Instance
resource "aws_instance" "wsk_bastion" {
  ami           = local.bastion_ami
  instance_type = "t3.micro"
  key_name      = aws_key_pair.wsk_bastion_key.key_name

  network_interface {
    network_interface_id = aws_network_interface.wsk_bastion_eni.id
    device_index         = 0
  }

  iam_instance_profile = aws_iam_instance_profile.wsk_bastion_profile.name

  user_data = base64encode(<<-EOF
#!/bin/bash
sed -i 's/#Port 22/Port 2202/' /etc/ssh/sshd_config
systemctl restart sshd

dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.7/2025-08-03/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
dnf install -y mariadb105
EOF
  )

  tags = {
    Name = "wsk-bastion"
  }

  depends_on = [aws_eip.wsk_bastion_eip]
}