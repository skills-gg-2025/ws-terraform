# Generate TLS private key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair for EC2 instances
resource "aws_key_pair" "main" {
  key_name   = "gj2025-keypair"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "gj2025-keypair"
  }
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = tls_private_key.main.private_key_pem
  filename = "gj2025-keypair.pem"
  file_permission = "0600"
}

# Elastic IP for Bastion Server
resource "aws_eip" "bastion" {
  domain = "vpc"
  tags = {
    Name = "gj2025-bastion-eip"
  }
}

# Security Group for Bastion Server
resource "aws_security_group" "bastion" {
  name        = "gj2025-bastion-sg"
  description = "Security group for bastion server"
  vpc_id      = aws_vpc.hub.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2222
    to_port     = 2222
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
    Name = "gj2025-bastion-sg"
  }
}

# IAM Role for Bastion Server
resource "aws_iam_role" "bastion" {
  name = "gj2025-bastion-role"

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
    Name = "gj2025-admin-role"
  }
}

# Attach AdministratorAccess policy to Bastion Role
resource "aws_iam_role_policy_attachment" "bastion" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# IAM Instance Profile for Bastion Server
resource "aws_iam_instance_profile" "bastion" {
  name = "gj2025-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name = "gj2025-bastion-profile"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                         = "ami-0ae2c887094315bed"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.hub_public_a.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
#!/bin/bash
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd
yum update -y
yum install -y git
yum install -y httpd-tools
yum install -y mariadb105
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2025-05-01/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
EOF
  )

  tags = {
    Name = "gj2025-bastion"
  }
}

# Associate Elastic IP with Bastion Instance
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}