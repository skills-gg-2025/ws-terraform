# Data source for Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for Bastion
resource "aws_iam_role" "admin_role" {
  name = "admin-role"
  
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
resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = aws_iam_role.admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "admin_profile" {
  name = "admin-profile"
  role = aws_iam_role.admin_role.name
}

# Security Group for Bastion
resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.hub.id
  
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
    Name = "wsc2025-bastion-eip"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                         = "ami-00ca32bbc84273381"
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.hub_pub_a.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.admin_profile.name
  associate_public_ip_address = true
  
  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y mariadb105
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.3/2025-04-17/bin/linux/amd64/kubectl
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
    Name = "wsc2025-bastion"
  }
}

# Associate EIP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
  depends_on    = [aws_instance.bastion, aws_eip.bastion_eip]
}