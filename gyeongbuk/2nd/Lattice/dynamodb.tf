# DynamoDB Table
resource "aws_dynamodb_table" "app_table" {
  name         = "skills-app-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "UserId"

  attribute {
    name = "UserId"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = true

  tags = {
    Name = "skills-app-table"
  }
}

# IAM Role for EC2 instances to access DynamoDB
resource "aws_iam_role" "ec2_dynamodb" {
  name = "skills-ec2-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_dynamodb" {
  name = "skills-ec2-dynamodb-policy"
  role = aws_iam_role.ec2_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.app_table.arn,
          "${aws_dynamodb_table.app_table.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_dynamodb" {
  name = "skills-ec2-dynamodb-profile"
  role = aws_iam_role.ec2_dynamodb.name
}
