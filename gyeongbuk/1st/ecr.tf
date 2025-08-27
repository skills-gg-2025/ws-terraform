# ECR Repository for Green application
resource "aws_ecr_repository" "green_repo" {
  name                 = "skills-green-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "skills-green-repo"
  }
}

# ECR Repository for Red application
resource "aws_ecr_repository" "red_repo" {
  name                 = "skills-red-repo"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "skills-red-repo"
  }
}

# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Build and push Green Docker image
resource "terraform_data" "green_docker_build" {
  triggers_replace = {
    dockerfile_hash = filemd5("${path.module}/src/green_1.0.0/Dockerfile")
    binary_hash     = filemd5("${path.module}/src/green_1.0.0/green_1.0.0")
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command     = "docker build --platform linux/amd64 -t ${aws_ecr_repository.green_repo.repository_url}:v1.0.0 ."
    working_dir = "${path.module}/src/green_1.0.0"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.green_repo.repository_url}:v1.0.0"
  }

  depends_on = [aws_ecr_repository.green_repo]
}

# Build and push Red Docker image
resource "terraform_data" "red_docker_build" {
  triggers_replace = {
    dockerfile_hash = filemd5("${path.module}/src/red_1.0.0/Dockerfile")
    binary_hash     = filemd5("${path.module}/src/red_1.0.0/red_1.0.0")
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command     = "docker build --platform linux/amd64 -t ${aws_ecr_repository.red_repo.repository_url}:v1.0.0 ."
    working_dir = "${path.module}/src/red_1.0.0"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.red_repo.repository_url}:v1.0.0"
  }

  depends_on = [aws_ecr_repository.red_repo]
}