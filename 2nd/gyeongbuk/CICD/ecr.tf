# ECR Repositories
resource "aws_ecr_repository" "product_dev" {
  name                 = "product/dev"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "product-dev"
  }
}

resource "aws_ecr_repository" "product_prod" {
  name                 = "product/prod"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "product-prod"
  }
}

resource "terraform_data" "ecr" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.eu-central-1.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build --platform linux/amd64 -t ${aws_ecr_repository.product_dev.repository_url}:initial ${path.module}/src
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker tag ${aws_ecr_repository.product_dev.repository_url}:initial ${aws_ecr_repository.product_prod.repository_url}:initial
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.product_dev.repository_url}:initial
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.product_prod.repository_url}:initial
    EOT
  }
}