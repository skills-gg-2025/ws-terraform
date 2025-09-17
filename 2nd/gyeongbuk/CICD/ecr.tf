# ECR Repositories
resource "aws_ecr_repository" "product_dev" {
  name         = "product/dev"
  force_delete = true

  tags = {
    Name = "product-dev"
  }
}

resource "aws_ecr_repository" "product_prod" {
  name         = "product/prod"
  force_delete = true

  tags = {
    Name = "product-prod"
  }
}

resource "aws_ecr_repository" "runner" {
  name         = "runner"
  force_delete = true

  tags = {
    Name = "runner"
  }
}

resource "terraform_data" "app" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker buildx create --use --name multiarch
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --cache-to type=registry,ref=${aws_ecr_repository.product_dev.repository_url}:cache \
        --cache-to type=registry,ref=${aws_ecr_repository.product_prod.repository_url}:cache \
        --push \
        -t ${aws_ecr_repository.product_dev.repository_url}:initial \
        -t ${aws_ecr_repository.product_prod.repository_url}:initial \
        ${path.module}/src
    EOT
  }
}

resource "terraform_data" "runner" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build --platform linux/amd64 -t ${aws_ecr_repository.runner.repository_url}:latest ${path.module}/src/runner
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.runner.repository_url}:latest
    EOT
  }
}