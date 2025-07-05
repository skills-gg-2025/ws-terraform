// ECR Repository Configuration
resource "aws_ecr_repository" "moni_api" {
  name                 = "monitoring/moni-api"
  image_tag_mutability = "IMMUTABLE" // Prevents overwriting of existing tags
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "moni-api"
  }
}

// Docker build and push to ECR using terraform_data
resource "terraform_data" "docker_build_push" {
  triggers_replace = {
    ecr_repository_url = aws_ecr_repository.moni_api.repository_url
    src_hash           = filemd5("${path.module}/src/app.py")
    dockerfile_hash    = filemd5("${path.module}/src/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build -t ${aws_ecr_repository.moni_api.repository_url}:v1.0.0 ${path.module}/src
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.moni_api.repository_url}:v1.0.0
    EOT
  }

  depends_on = [aws_ecr_repository.moni_api]
}