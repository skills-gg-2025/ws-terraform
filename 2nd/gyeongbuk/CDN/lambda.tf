# IAM role for Lambda invalidation (KR)
resource "aws_iam_role" "lambda_invalidation_kr" {
  provider = aws.korea
  name     = "skills-lambda-role-kr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "skills-lambda-role-kr"
  }
}

# IAM role for Lambda invalidation (US)
resource "aws_iam_role" "lambda_invalidation_us" {
  provider = aws.us
  name     = "skills-lambda-role-us"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "skills-lambda-role-us"
  }
}

# IAM policy for Lambda invalidation (KR)
resource "aws_iam_role_policy" "lambda_invalidation_kr" {
  provider = aws.korea
  name     = "skills-lambda-invalidation-policy-kr"
  role     = aws_iam_role.lambda_invalidation_kr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for Lambda invalidation (US)
resource "aws_iam_role_policy" "lambda_invalidation_us" {
  provider = aws.us
  name     = "skills-lambda-invalidation-policy-us"
  role     = aws_iam_role.lambda_invalidation_us.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = "*"
      }
    ]
  })
}

# Archive Lambda invalidation function (KR)
data "archive_file" "lambda_invalidation_kr_zip" {
  type        = "zip"
  source_file = "${path.module}/src/lambda-invalidation-kr.py"
  output_path = "${path.module}/src/lambda-invalidation-kr.zip"
}

# Archive Lambda invalidation function (US)
data "archive_file" "lambda_invalidation_us_zip" {
  type        = "zip"
  source_file = "${path.module}/src/lambda-invalidation-us.py"
  output_path = "${path.module}/src/lambda-invalidation-us.zip"
}

# Lambda function for invalidation (KR)
resource "aws_lambda_function" "invalidation_kr" {
  provider         = aws.korea
  filename         = data.archive_file.lambda_invalidation_kr_zip.output_path
  function_name    = "skills-lambda-function-kr"
  role             = aws_iam_role.lambda_invalidation_kr.arn
  handler          = "lambda-invalidation-kr.lambda_handler"
  source_code_hash = data.archive_file.lambda_invalidation_kr_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 60

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.main.id
    }
  }

  tags = {
    Name = "skills-lambda-function-kr"
  }
}

# Lambda function for invalidation (US)
resource "aws_lambda_function" "invalidation_us" {
  provider         = aws.us
  filename         = data.archive_file.lambda_invalidation_us_zip.output_path
  function_name    = "skills-lambda-function-us"
  role             = aws_iam_role.lambda_invalidation_us.arn
  handler          = "lambda-invalidation-us.lambda_handler"
  source_code_hash = data.archive_file.lambda_invalidation_us_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 60

  environment {
    variables = {
      CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.main.id
    }
  }

  tags = {
    Name = "skills-lambda-function-us"
  }
}

# Lambda permission for S3 to invoke KR function
resource "aws_lambda_permission" "s3_invoke_kr" {
  provider      = aws.korea
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invalidation_kr.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.kr_static.arn
}

# Lambda permission for S3 to invoke US function
resource "aws_lambda_permission" "s3_invoke_us" {
  provider      = aws.us
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invalidation_us.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.us_static.arn
}
