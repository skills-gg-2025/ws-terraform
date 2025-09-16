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

# Key Pair for Bastion
resource "aws_key_pair" "bastion_key" {
  key_name   = "ws25-bastion-key"
  public_key = file("./src/ws25-bastion-key.pem.pub")
}

# IAM Role for Bastion with full AWS access
resource "aws_iam_role" "bastion_role" {
  name = "ws25-bastion-role"
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
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "ws25-bastion-role"
  role = aws_iam_role.bastion_role.name
}

# Elastic IP for Bastion
resource "aws_eip" "bastion_eip" {
  domain = "vpc"
}

# Security Group for Bastion with custom SSH port
resource "aws_security_group" "bastion_sg" {
  name_prefix = "ws25-bastion-sg"
  vpc_id      = aws_vpc.hub_vpc.id

  ingress {
    from_port   = 10100
    to_port     = 10100
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
    Name = "ws25-bastion-sg"
  }
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                     = data.aws_ami.amazon_linux.id
  instance_type           = "t3.small"
  key_name                = aws_key_pair.bastion_key.key_name
  subnet_id               = aws_subnet.hub_pub_c.id
  vpc_security_group_ids  = [aws_security_group.bastion_sg.id]
  iam_instance_profile    = aws_iam_instance_profile.bastion_profile.name
  disable_api_termination = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y zip mariadb105
    sed -i 's/#Port 22/Port 10100/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = {
    Name = "ws25-ec2-bastion"
  }
}

# Associate Elastic IP with Bastion
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}

# Copy and configure pipeline folder
resource "null_resource" "bastion_pipeline_setup" {
  depends_on = [
    aws_secretsmanager_secret_version.db_secret_version,
    aws_eip_association.bastion_eip_assoc
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./src/ws25-bastion-key.pem")
    host        = aws_eip.bastion_eip.public_ip
    port        = 10100
  }

  provisioner "file" {
    source      = "./src/pipeline"
    destination = "/home/ec2-user/pipeline"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/<ACCOUNT_ID>/${data.aws_caller_identity.current.account_id}/g' /home/ec2-user/pipeline/artifact/green/imageDetail.json",
      "sed -i 's/<ACCOUNT_ID>/${data.aws_caller_identity.current.account_id}/g' /home/ec2-user/pipeline/artifact/red/imageDetail.json",
      "sed -i 's|<SECRET_ARN>|${aws_secretsmanager_secret.db_secret.arn}|g' /home/ec2-user/pipeline/artifact/green/taskdef.json",
      "sed -i 's|<SECRET_ARN>|${aws_secretsmanager_secret.db_secret.arn}|g' /home/ec2-user/pipeline/artifact/red/taskdef.json",
      "sed -i 's/<ACCOUNT_ID>/${data.aws_caller_identity.current.account_id}/g' /home/ec2-user/pipeline/artifact/green/taskdef.json",
      "sed -i 's/<ACCOUNT_ID>/${data.aws_caller_identity.current.account_id}/g' /home/ec2-user/pipeline/artifact/red/taskdef.json",
      "sed -i 's/<NUM>/${var.number}/g' /home/ec2-user/pipeline/green.sh",
      "sed -i 's/<NUM>/${var.number}/g' /home/ec2-user/pipeline/red.sh",
      "sed -i 's/ws25-fluent-config-<NUM>/ws25-fluent-config-${var.number}/g' /home/ec2-user/pipeline/artifact/green/taskdef.json",
      "sed -i 's/ws25-fluent-config-<NUM>/ws25-fluent-config-${var.number}/g' /home/ec2-user/pipeline/artifact/red/taskdef.json",
      "chmod +x /home/ec2-user/pipeline/green.sh",
      "chmod +x /home/ec2-user/pipeline/red.sh"
    ]
  }
}

# Remote exec provisioner to setup MySQL and execute SQL
resource "null_resource" "bastion_mysql_setup" {
  depends_on = [
    aws_rds_cluster_instance.aurora_instance_writer,
    null_resource.bastion_pipeline_setup
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./src/ws25-bastion-key.pem")
    host        = aws_eip.bastion_eip.public_ip
    port        = 10100
  }

  provisioner "file" {
    source      = "./src/day1_table_v1.sql"
    destination = "/tmp/day1_table_v1.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "mysql -h ${aws_rds_cluster.aurora_cluster.endpoint} -u ${var.username} -P 10101 -p${var.password} day1 < /tmp/day1_table_v1.sql"
    ]
  }
}
