data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_iam_role" "bastion_role" {
  name = "nsl-bastion-role"

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

resource "aws_iam_role_policy_attachment" "bastion_admin_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "nsl-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "nsl-bastion-sg"
  vpc_id      = data.aws_vpc.default.id

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

resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "bastion_key_pair" {
  key_name   = "nsl-bastion-key"
  public_key = tls_private_key.bastion_key.public_key_openssh
}

resource "local_file" "bastion_private_key" {
  content  = tls_private_key.bastion_key.private_key_pem
  filename = "${path.module}/nsl-bastion-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  key_name               = aws_key_pair.bastion_key_pair.key_name

  tags = {
    Name = "nsl-bastion"
  }
}