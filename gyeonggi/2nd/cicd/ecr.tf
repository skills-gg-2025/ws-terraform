# ECR Repository
resource "aws_ecr_repository" "cicd_application" {
  name         = "ws-cicd-repository/cicd-application"
  force_delete = true

  tags = {
    Name = "cicd-application"
  }
}

resource "terraform_data" "docker_build_push" {
  triggers_replace = {
    ecr_repository_url = aws_ecr_repository.cicd_application.repository_url
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
      docker build -t ${aws_ecr_repository.cicd_application.repository_url}:v1.0.0 ${path.module}/src
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.cicd_application.repository_url}:v1.0.0
    EOT
  }
}