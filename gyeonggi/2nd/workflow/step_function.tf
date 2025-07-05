# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "ws-workflow-lambda-role"

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

# IAM policy for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "ws-workflow-lambda-policy"
  role = aws_iam_role.lambda_role.id

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
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.workflow_bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = aws_dynamodb_table.consumer_id.arn
      }
    ]
  })
}

# Lambda function - Extract Transform
resource "aws_lambda_function" "extract_transform" {
  filename         = "extract_transform.zip"
  function_name    = "Extract_Transform"
  role             = aws_iam_role.lambda_role.arn
  handler          = "extract_transform.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.extract_transform_zip.output_base64sha256

  layers = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-pandas:17"]
}

# Lambda function - DynamoDB Load
resource "aws_lambda_function" "dynamodb_load" {
  filename         = "dynamodb_load.zip"
  function_name    = "Dynamodb_load"
  role             = aws_iam_role.lambda_role.arn
  handler          = "dynamodb_load.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.dynamodb_load_zip.output_base64sha256

  layers = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-pandas:17"]
}

# Archive files for Lambda functions
data "archive_file" "extract_transform_zip" {
  type        = "zip"
  source_file = "${path.module}/src/extract_transform.py"
  output_path = "extract_transform.zip"
}

data "archive_file" "dynamodb_load_zip" {
  type        = "zip"
  source_file = "${path.module}/src/dynamodb_load.py"
  output_path = "dynamodb_load.zip"
}



# IAM role for Step Functions
resource "aws_iam_role" "stepfunction_role" {
  name = "ws-workflow-stepfunction-role"

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

# IAM policy for Step Functions
resource "aws_iam_role_policy" "stepfunction_policy" {
  name = "ws-workflow-stepfunction-policy"
  role = aws_iam_role.stepfunction_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.extract_transform.arn,
          aws_lambda_function.dynamodb_load.arn
        ]
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "workflow" {
  name     = "ws-day2-StepFunction-${var.number}"
  role_arn = aws_iam_role.stepfunction_role.arn

  definition = jsonencode({
    Comment = "Workflow for data processing"
    StartAt = "Extract_Transform"
    States = {
      Extract_Transform = {
        Type     = "Task"
        Resource = aws_lambda_function.extract_transform.arn
        Next     = "Dynamodb_load"
      }
      Dynamodb_load = {
        Type     = "Task"
        Resource = aws_lambda_function.dynamodb_load.arn
        End      = true
      }
    }
  })
}