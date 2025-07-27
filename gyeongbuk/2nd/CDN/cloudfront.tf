# IAM role for Lambda@Edge
resource "aws_iam_role" "lambda_edge" {
  provider = aws.us
  name     = "skills-cdn-edge-function-role"

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

# IAM policy for Lambda@Edge
resource "aws_iam_role_policy_attachment" "lambda_edge_execution" {
  provider   = aws.us
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_edge.name
}

# IAM policy for Lambda@Edge S3 access
resource "aws_iam_role_policy" "lambda_edge_s3" {
  provider = aws.us
  name     = "lambda-edge-s3-policy"
  role     = aws_iam_role.lambda_edge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.kr_static.arn}/*",
          "${aws_s3_bucket.us_static.arn}/*",
          "arn:aws:s3::${data.aws_caller_identity.current.account_id}:accesspoint/${aws_s3control_multi_region_access_point.mrap.alias}/*"
        ]
      }
    ]
  })
}

# Lambda@Edge function (must be in us-east-1)
resource "aws_lambda_function" "edge_function" {
  provider         = aws.us
  filename         = "${path.module}/src/deployment-package.zip"
  function_name    = "skills-cdn-edge-function"
  role             = aws_iam_role.lambda_edge.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/src/deployment-package.zip")
  runtime          = "python3.9"
  timeout          = 30

  publish = true

  tags = {
    Name = "skills-cdn-edge-function"
  }
}

# Archive Lambda@Edge function
# data "archive_file" "lambda_edge_zip" {
#   type        = "zip"
#   output_path = "${path.module}/src/lambda-edge-function.zip"

#   source {
#     content  = file("${path.module}/src/lambda-edge-function.py")
#     filename = "lambda_function.py"
#   }
# }

# CloudFront Function
resource "aws_cloudfront_function" "viewer_request" {
  provider = aws.us
  name     = "skills-cf-function"
  runtime  = "cloudfront-js-1.0"
  comment  = "Function for country and user-agent blocking"
  publish  = true
  code     = file("${path.module}/src/cloudfront-function.js")
}

# Origin Access Control for CloudFront
resource "aws_cloudfront_origin_access_control" "main" {
  provider                          = aws.us
  name                              = "skills-mrap-oac"
  description                       = "OAC for S3 MRAP access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  provider = aws.us

  origin {
    domain_name = "${aws_s3control_multi_region_access_point.mrap.alias}.accesspoint.s3-global.amazonaws.com"
    origin_id   = "S3-MRAP-skills-mrap"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-MRAP-skills-mrap"

    forwarded_values {
      query_string = false
      headers      = ["CloudFront-Viewer-Country"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # CloudFront Function association
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_request.arn
    }

    # Lambda@Edge association
    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.edge_function.qualified_arn
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
    Name = "skills-global-distribution"
  }
}
