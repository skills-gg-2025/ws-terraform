# ECR Repositories
resource "aws_ecr_repository" "grapp" {
  name                 = "wsk1/grapp"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.wsk_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "wsk1/grapp"
  }
}

resource "aws_ecr_repository" "reapp" {
  name                 = "wsk1/reapp"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.wsk_key.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "wsk1/reapp"
  }
}

# Replication Configuration
resource "aws_ecr_replication_configuration" "wsk_ecr_replication" {
  replication_configuration {
    rule {
      destination {
        region      = "us-east-1"
        registry_id = data.aws_caller_identity.current.account_id
      }
      destination {
        region      = "eu-central-1"
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}

data "aws_caller_identity" "current" {}

# Get Bastion Host IP
data "aws_instance" "bastion" {
  instance_id = aws_instance.wsk_bastion.id
}

# Wait for bastion initialization
resource "time_sleep" "wait_for_bastion" {
  create_duration = "90s"
  
  depends_on = [
    aws_instance.wsk_bastion
  ]
}

# Copy source files and build images
resource "null_resource" "build_and_push_images" {
  provisioner "file" {
    source      = "src/green"
    destination = "/home/ec2-user/green"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("wsk-bastion-key.pem")
      host        = data.aws_instance.bastion.public_ip
      port        = 2202
    }
  }
  
  provisioner "file" {
    source      = "src/red"
    destination = "/home/ec2-user/red"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("wsk-bastion-key.pem")
      host        = data.aws_instance.bastion.public_ip
      port        = 2202
    }
  }
  
  provisioner "file" {
    source      = "src/build_and_push.sh"
    destination = "/home/ec2-user/build_and_push.sh"
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("wsk-bastion-key.pem")
      host        = data.aws_instance.bastion.public_ip
      port        = 2202
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/build_and_push.sh",
      "cd /home/ec2-user && ./build_and_push.sh"
    ]
    
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("wsk-bastion-key.pem")
      host        = data.aws_instance.bastion.public_ip
      port        = 2202
    }
  }
  
  depends_on = [
    aws_ecr_repository.grapp,
    aws_ecr_repository.reapp,
    time_sleep.wait_for_bastion
  ]
}