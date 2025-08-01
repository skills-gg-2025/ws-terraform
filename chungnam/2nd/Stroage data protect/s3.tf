resource "aws_s3_bucket" "sensitive_data" {
  bucket = "wsc2025-sensitive-${var.bucket_suffix}"

  tags = {
    Name = "wsc2025-sensitive-${var.bucket_suffix}"
  }
}

resource "aws_s3_bucket_versioning" "sensitive_data" {
  bucket = aws_s3_bucket.sensitive_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Create folders (prefixes) in S3
resource "aws_s3_object" "masked_folder" {
  bucket = aws_s3_bucket.sensitive_data.id
  key    = "masked/"
  content = ""
}

resource "aws_s3_object" "incoming_folder" {
  bucket = aws_s3_bucket.sensitive_data.id
  key    = "incoming/"
  content = ""
}

# Upload deploy_file files to incoming/
resource "aws_s3_object" "deploy_files" {
  for_each = fileset("./deploy_file", "*")
  bucket   = aws_s3_bucket.sensitive_data.id
  key      = "incoming/${each.value}"
  source   = "./deploy_file/${each.value}"
  etag     = filemd5("./deploy_file/${each.value}")
}

resource "aws_s3_bucket_notification" "lambda_trigger" {
  bucket = aws_s3_bucket.sensitive_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.masking_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
  }

  depends_on = [aws_lambda_permission.s3_invoke, aws_s3_object.deploy_files]
}