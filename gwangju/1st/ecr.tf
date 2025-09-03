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

# Build and push Red Docker image
resource "terraform_data" "red_docker_build" {
  triggers_replace = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command     = "docker build --platform linux/amd64 -t ${aws_ecr_repository.red.repository_url}:latest ."
    working_dir = "${path.module}/src/red"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.red.repository_url}:latest"
  }

  depends_on = [aws_ecr_repository.red]
}

# Build and push Green Docker image
resource "terraform_data" "green_docker_build" {
  triggers_replace = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command     = "docker build --platform linux/amd64 -t ${aws_ecr_repository.green.repository_url}:latest ."
    working_dir = "${path.module}/src/green"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.green.repository_url}:latest"
  }

  depends_on = [aws_ecr_repository.green]
}