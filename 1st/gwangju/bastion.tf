# Elastic IP for Bastion Server
resource "aws_eip" "bastion" {
  domain = "vpc"
}

# Security Group for Bastion Server
resource "aws_security_group" "bastion" {
  name        = "gj2025-bastion-sg"
  description = "Security group for bastion server"
  vpc_id      = aws_vpc.hub.id

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
  private_ip                  = "10.0.0.254"

  user_data_base64 = base64encode(<<-EOF
#!/bin/bash
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart sshd
yum update -y
yum install -y git jq
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
echo "bastion-ready" > /tmp/bastion-setup-complete
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

# Copy k8s files to bastion
resource "null_resource" "copy_k8s_files" {
  depends_on = [aws_eip_association.bastion]
  
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for bastion setup to complete...'",
      "while [ ! -f /tmp/bastion-setup-complete ]; do",
      "  echo 'Bastion setup still in progress...'",
      "  sleep 10",
      "done",
      "echo 'Bastion setup completed!'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./gj2025-key.pem")
      host        = aws_eip.bastion.public_ip
      port        = 2222
      timeout     = "8m"
    }
  }
  
  provisioner "file" {
    source      = "${path.module}/src/k8s"
    destination = "/tmp"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./gj2025-key.pem")
      host        = aws_eip.bastion.public_ip
      port        = 2222
      timeout     = "8m"
    }
  }
  
  provisioner "file" {
    source      = "${path.module}/src/day1_table_v1.sql"
    destination = "/tmp/day1_table_v1.sql"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./gj2025-key.pem")
      host        = aws_eip.bastion.public_ip
      port        = 2222
      timeout     = "8m"
    }
  }
  
  triggers = {
    always_run = timestamp()
  }
}