variable "bucket_suffix" {
  description = "4-character suffix for S3 bucket name"
  type        = string
}

resource "aws_s3_bucket" "app_bucket" {
  bucket = "wsc2025-app-${var.bucket_suffix}"
  
  tags = {
    Name = "wsc2025-app-bucket"
  }
}

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_encryption" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket_pab" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "app_bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codepipeline_role.arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.app_bucket.arn}/source/green/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codepipeline_role.arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.app_bucket.arn}/source/red/*"
      }
    ]
  })
}

