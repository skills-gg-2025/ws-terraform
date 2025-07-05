# S3 Bucket for Data Storage
resource "aws_s3_bucket" "ws_day2_data" {
  bucket        = "ws-day2-data-${var.number}-s3"
  force_destroy = true

  tags = {
    Name = "ws-day2-data-${var.number}-s3"
  }
}

# S3 Bucket for Athena
resource "aws_s3_bucket" "ws_day2_athena" {
  bucket        = "ws-day2-athena-${var.number}-s3"
  force_destroy = true

  tags = {
    Name = "ws-day2-athena-${var.number}-s3"
  }
}