# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = "app-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "app-repo"
  }
}

# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Build and push Docker image
resource "terraform_data" "docker_build_push" {
  triggers_replace = {
    dockerfile_hash = filemd5("./src/Dockerfile")
    index_html_hash = filemd5("./src/index.html")
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command     = "docker build --platform linux/amd64 -t ${aws_ecr_repository.app_repo.repository_url}:v1.0.0 ."
    working_dir = "${path.module}/src"
  }

  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.app_repo.repository_url}:v1.0.0"
  }

  depends_on = [aws_ecr_repository.app_repo]
}