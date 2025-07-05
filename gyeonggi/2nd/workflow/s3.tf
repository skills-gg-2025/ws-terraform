# S3 bucket for workflow data
resource "aws_s3_bucket" "workflow_bucket" {
  bucket        = "ws-day2-workflow-${var.number}-s3"
  force_destroy = true
}

# Upload creditcard.csv to S3 bucket
resource "aws_s3_object" "creditcard_csv" {
  bucket = aws_s3_bucket.workflow_bucket.id
  key    = "creditcard.csv"
  source = "${path.module}/src/creditcard.csv"
  etag   = filemd5("${path.module}/src/creditcard.csv")
}