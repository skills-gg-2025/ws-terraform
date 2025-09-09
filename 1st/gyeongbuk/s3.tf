# Random string for unique bucket naming
resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

# S3 Bucket for binary storage
resource "aws_s3_bucket" "skills_chart_bucket" {
  bucket = "skills-chart-bucket-${random_string.bucket_suffix.result}"

  tags = {
    Name = "skills-chart-bucket-${random_string.bucket_suffix.result}"
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "skills_chart_bucket_versioning" {
  bucket = aws_s3_bucket.skills_chart_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "skills_chart_bucket_pab" {
  bucket = aws_s3_bucket.skills_chart_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload green binary v1.0.1
resource "aws_s3_object" "green_binary" {
  bucket      = aws_s3_bucket.skills_chart_bucket.id
  key         = "images/green_1.0.1"
  source      = "${path.module}/src/green_1.0.1"
  source_hash = filemd5("${path.module}/src/green_1.0.1")

  tags = {
    Name = "green-binary-v1.0.1"
  }
}

# Upload red binary v1.0.1
resource "aws_s3_object" "red_binary" {
  bucket      = aws_s3_bucket.skills_chart_bucket.id
  key         = "images/red_1.0.1"
  source      = "${path.module}/src/red_1.0.1"
  source_hash = filemd5("${path.module}/src/red_1.0.1")

  tags = {
    Name = "red-binary-v1.0.1"
  }
}

# Upload App
resource "aws_s3_object" "app_tar" {
  bucket      = aws_s3_bucket.skills_chart_bucket.id
  key         = "app/app-0.1.0.tgz"
  source      = "${path.module}/src/k8s/app/app-0.1.0.tgz"
  source_hash = filemd5("${path.module}/src/k8s/app/app-0.1.0.tgz")

  tags = {
    Name = "app-0.1.0"
  }
}

resource "aws_s3_object" "app_index" {
  bucket      = aws_s3_bucket.skills_chart_bucket.id
  key         = "app/index.yaml"
  source      = "${path.module}/src/k8s/app/index.yaml"
  source_hash = filemd5("${path.module}/src/k8s/app/index.yaml")

  tags = {
    Name = "app-index"
  }
}