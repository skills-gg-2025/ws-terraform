terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["~/.aws/credentials"]
  shared_config_files      = ["~/.aws/config"]
  profile                  = "default"
}

# S3 Bucket
resource "aws_s3_bucket" "file_storage" {
  bucket = "save-file-s3-bucket-${var.bucket_random_number}-${var.player_number}"
}

resource "aws_s3_bucket_public_access_block" "file_storage_pab" {
  bucket = aws_s3_bucket.file_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "file_storage_encryption" {
  bucket = aws_s3_bucket.file_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Create file directory in S3
resource "aws_s3_object" "file_directory" {
  bucket = aws_s3_bucket.file_storage.id
  key    = "file/"
}

# DynamoDB Tables
resource "aws_dynamodb_table" "application_table" {
  name           = "application-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "file-type"
  range_key      = "file-name"

  attribute {
    name = "file-type"
    type = "S"
  }

  attribute {
    name = "file-name"
    type = "S"
  }
}

resource "aws_dynamodb_table" "data_table" {
  name           = "data-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "file-type"
  range_key      = "file-name"

  attribute {
    name = "file-type"
    type = "S"
  }

  attribute {
    name = "file-name"
    type = "S"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "work-lambda-role"

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
}

# AWS Managed Policy for Lambda Basic Execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# AWS Managed Policy for VPC Access (if needed)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom Policy for S3 and DynamoDB Access
resource "aws_iam_role_policy" "lambda_policy" {
  name = "work-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.file_storage.arn,
          "${aws_s3_bucket.file_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.application_table.arn,
          aws_dynamodb_table.data_table.arn,
          "${aws_dynamodb_table.application_table.arn}/*",
          "${aws_dynamodb_table.data_table.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "work-lambda-functions.py"
  output_path = "work-lambda-functions.zip"
}

resource "aws_lambda_function" "work_lambda" {
  filename         = "work-lambda-functions.zip"
  function_name    = "work-lambda-functions"
  role            = aws_iam_role.lambda_role.arn
  handler         = "work-lambda-functions.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 60
}

# S3 Bucket Notification
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.file_storage.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.work_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "file/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.work_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.file_storage.arn
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "step-workflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# AWS Managed Policy for Step Functions
resource "aws_iam_role_policy_attachment" "step_functions_execution" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

# Custom Policy for Step Functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "step-workflow-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        Resource = [
          aws_lambda_function.work_lambda.arn,
          "${aws_lambda_function.work_lambda.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "step_workflow" {
  name     = "step-workflow"
  role_arn = aws_iam_role.step_functions_role.arn

  definition = jsonencode({
    Comment = "File processing workflow"
    StartAt = "ProcessFile"
    States = {
      ProcessFile = {
        Type     = "Task"
        Resource = aws_lambda_function.work_lambda.arn
        End      = true
      }
    }
  })
}