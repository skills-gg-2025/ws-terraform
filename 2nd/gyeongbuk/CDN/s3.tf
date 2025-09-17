# S3 bucket for Korea region
resource "aws_s3_bucket" "kr_static" {
  provider      = aws.korea
  bucket        = "skills-kr-cdn-web-static-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "skills-kr-cdn-web-static-${data.aws_caller_identity.current.account_id}"
  }
}

# S3 bucket for US region
resource "aws_s3_bucket" "us_static" {
  provider      = aws.us
  bucket        = "skills-us-cdn-web-static-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "skills-us-cdn-web-static-${data.aws_caller_identity.current.account_id}"
  }
}

# S3 bucket versioning for KR
resource "aws_s3_bucket_versioning" "kr_static_versioning" {
  provider = aws.korea
  bucket   = aws_s3_bucket.kr_static.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket versioning for US
resource "aws_s3_bucket_versioning" "us_static_versioning" {
  provider = aws.us
  bucket   = aws_s3_bucket.us_static.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket public access block for KR
resource "aws_s3_bucket_public_access_block" "kr_static_pab" {
  provider = aws.korea
  bucket   = aws_s3_bucket.kr_static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket public access block for US
resource "aws_s3_bucket_public_access_block" "us_static_pab" {
  provider = aws.us
  bucket   = aws_s3_bucket.us_static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload KR content
resource "aws_s3_object" "kr_index" {
  provider = aws.korea
  bucket   = aws_s3_bucket.kr_static.id
  key      = "index.html"
  source   = "${path.module}/src/kr/index.html"
  etag     = filemd5("${path.module}/src/kr/index.html")

  content_type = "text/html"
}

# Upload US content
resource "aws_s3_object" "us_index" {
  provider = aws.us
  bucket   = aws_s3_bucket.us_static.id
  key      = "index.html"
  source   = "${path.module}/src/us/index.html"
  etag     = filemd5("${path.module}/src/us/index.html")

  content_type = "text/html"
}

# S3 Multi-Region Access Point
resource "aws_s3control_multi_region_access_point" "mrap" {
  provider = aws.korea

  details {
    name = "skills-mrap"

    public_access_block {
      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }

    region {
      bucket = aws_s3_bucket.kr_static.id
    }

    region {
      bucket = aws_s3_bucket.us_static.id
    }
  }
}

# IAM policy document for KR S3 bucket access
data "aws_iam_policy_document" "s3_kr_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.kr_static.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

# S3 bucket policy for KR
resource "aws_s3_bucket_policy" "kr_static_policy" {
  provider = aws.korea
  bucket   = aws_s3_bucket.kr_static.id
  policy   = data.aws_iam_policy_document.s3_kr_policy.json
}

# IAM policy document for US S3 bucket access
data "aws_iam_policy_document" "s3_us_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.us_static.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

# S3 bucket policy for US
resource "aws_s3_bucket_policy" "us_static_policy" {
  provider = aws.us
  bucket   = aws_s3_bucket.us_static.id
  policy   = data.aws_iam_policy_document.s3_us_policy.json
}

# S3 bucket notification for KR
resource "aws_s3_bucket_notification" "kr_bucket_notification" {
  provider = aws.korea
  bucket   = aws_s3_bucket.kr_static.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.invalidation_kr.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_kr]
}

# S3 bucket notification for US
resource "aws_s3_bucket_notification" "us_bucket_notification" {
  provider = aws.us
  bucket   = aws_s3_bucket.us_static.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.invalidation_us.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke_us]
}

# Note: MRAP policy removed due to long creation time in competition environment
# MRAP will work without explicit policy for this use case
