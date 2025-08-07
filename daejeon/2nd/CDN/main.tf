provider "aws" {
  region = "us-west-1"
}

# Random suffix for S3 bucket
resource "random_integer" "bucket_suffix" {
  min = 100
  max = 999
}

# S3 Bucket for DRM content
resource "aws_s3_bucket" "drm_bucket" {
  bucket = "web-drm-bucket-${random_integer.bucket_suffix.result}"
}

resource "aws_s3_bucket_public_access_block" "drm_bucket_pab" {
  bucket = aws_s3_bucket.drm_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload MP4 files to S3
resource "aws_s3_object" "mp4_files" {
  for_each = fileset("${path.module}/src", "*.mp4")

  bucket      = aws_s3_bucket.drm_bucket.id
  key         = "media/${each.value}"
  source      = "${path.module}/src/${each.value}"
  source_hash = filemd5("${path.module}/src/${each.value}")
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "drm_oac" {
  name                              = "web-drm-oac"
  description                       = "OAC for DRM bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "drm_bucket_policy" {
  bucket = aws_s3_bucket.drm_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.drm_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.web_cdn.arn
          }
        }
      }
    ]
  })
}

# Lambda@Edge function for DRM token validation
resource "aws_iam_role" "lambda_edge_role" {
  name = "web-drm-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_edge_role.name
}

# Lambda@Edge function
resource "aws_lambda_function" "drm_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "web-drm-function"
  role             = aws_iam_role.lambda_edge_role.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  publish          = true
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  depends_on = [data.archive_file.lambda_zip]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/web-drm-function.zip"
  source {
    content  = file("${path.module}/lambda/drm_function.py")
    filename = "index.py"
  }
}

# CloudFront Function
resource "aws_cloudfront_function" "web_cdn_function" {
  name    = "web-cdn-function"
  runtime = "cloudfront-js-2.0"
  code    = file("${path.module}/cloudfront/viewer_request.js")
}

# Cache Policy for DRM
resource "aws_cloudfront_cache_policy" "drm_cache_policy" {
  name        = "drm-cache-policy"
  comment     = "Cache policy for DRM content"
  default_ttl = 60
  max_ttl     = 60
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    query_strings_config {
      query_string_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["X-DRM-Token"]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "web_cdn" {
  origin {
    domain_name              = aws_s3_bucket.drm_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.drm_oac.id
    origin_id                = "S3-${aws_s3_bucket.drm_bucket.id}"
  }

  enabled = true
  comment = "web-cdn"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.drm_bucket.id}"
    cache_policy_id        = aws_cloudfront_cache_policy.drm_cache_policy.id
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.web_cdn_function.arn
    }

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.drm_function.qualified_arn
      include_body = false
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "web-cdn"
  }
}