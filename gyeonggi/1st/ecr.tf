# ECR Repository for Green Application
resource "aws_ecr_repository" "green" {
  name                 = "green"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR Repository for Red Application (with KMS encryption)
resource "aws_ecr_repository" "red" {
  name                 = "red"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.rds_key.arn
  }
}

resource "terraform_data" "green_100" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build -t ${aws_ecr_repository.green.repository_url}:v1.0.0 ${path.module}/src/green_1.0.0
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.green.repository_url}:v1.0.0
    EOT
  }
}

resource "terraform_data" "green_101" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build -t ${aws_ecr_repository.green.repository_url}:v1.0.1 ${path.module}/src/green_1.0.1
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.green.repository_url}:v1.0.1
    EOT
  }
}

resource "terraform_data" "red_100" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build -t ${aws_ecr_repository.red.repository_url}:v1.0.0 ${path.module}/src/red_1.0.0
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.red.repository_url}:v1.0.0
    EOT
  }
}

resource "terraform_data" "red_101" {
  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${data.aws_region.current.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker build -t ${aws_ecr_repository.red.repository_url}:v1.0.1 ${path.module}/src/red_1.0.1
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      docker push ${aws_ecr_repository.red.repository_url}:v1.0.1
    EOT
  }
}