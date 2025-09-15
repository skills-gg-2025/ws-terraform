# ECR Repository for Red application
resource "aws_ecr_repository" "red" {
  name                 = "red"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "red"
  }
}

# ECR Repository for Green application
resource "aws_ecr_repository" "green" {
  name                 = "green"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "green"
  }
}

# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Build and push Docker images on bastion
resource "null_resource" "docker_build" {
  depends_on = [
    aws_ecr_repository.red,
    aws_ecr_repository.green,
    null_resource.copy_k8s_files,
    aws_eks_node_group.addon,
    aws_eks_node_group.app
  ]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for bastion setup to complete...'",
      "while [ ! -f /tmp/bastion-setup-complete ]; do",
      "  echo 'Bastion setup still in progress...'",
      "  sleep 10",
      "done",
      "echo 'Building and pushing Docker images...'",
      "export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)",
      "aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com",
      "docker build --platform linux/amd64 -t $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/red:latest /tmp/k8s/argocd/red/app-red/",
      "docker build --platform linux/amd64 -t $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/green:latest /tmp/k8s/argocd/green/app-green/",
      "docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/red:latest",
      "docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/green:latest",
      "echo 'Docker images pushed successfully!'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./gj2025-key.pem")
      host        = aws_eip.bastion.public_ip
      port        = 2222
      timeout     = "10m"
    }
  }

  triggers = {
    always_run = timestamp()
  }
}