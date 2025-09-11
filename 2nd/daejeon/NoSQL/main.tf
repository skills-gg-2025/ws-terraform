provider "aws" {
  region = "ap-northeast-2"
  alias  = "primary"
}

provider "aws" {
  region = "eu-central-1"
  alias  = "secondary"
}

# DynamoDB Global Table
resource "aws_dynamodb_table" "account_table" {
  provider     = aws.primary
  name         = "account-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "account_id"

  attribute {
    name = "account_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  replica {
    region_name            = "eu-central-1"
    point_in_time_recovery = true
  }

  tags = {
    Name = "account-table"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  provider = aws.primary
  name     = "account-conflict-resolver-role"

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

resource "aws_iam_role_policy" "lambda_policy" {
  provider = aws.primary
  name     = "account-conflict-resolver-policy"
  role     = aws_iam_role.lambda_role.id

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
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.account_table.arn,
          "${aws_dynamodb_table.account_table.arn}/*"
        ]
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "conflict_resolver" {
  provider      = aws.primary
  filename      = "conflict_resolver.zip"
  function_name = "account-conflict-resolver"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  depends_on = [data.archive_file.lambda_zip]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "conflict_resolver.zip"
  source {
    content  = file("${path.module}/lambda/conflict_resolver.py")
    filename = "lambda_function.py"
  }
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "account_conflict_event" {
  provider    = aws.primary
  name        = "account-conflict-event"
  description = "account-conflict-event"

  event_pattern = jsonencode({
    source      = ["aws.dynamodb"]
    detail-type = ["DynamoDB Stream Record"]
    detail = {
      eventName = ["MODIFY", "INSERT"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  provider  = aws.primary
  rule      = aws_cloudwatch_event_rule.account_conflict_event.name
  target_id = "ConflictResolverTarget"
  arn       = aws_lambda_function.conflict_resolver.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  provider      = aws.primary
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.conflict_resolver.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.account_conflict_event.arn
}

# VPC Configuration
resource "aws_vpc" "main" {
  provider             = aws.primary
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "account-app-vpc"
  }
}

resource "aws_subnet" "main" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "account-app-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  provider = aws.primary
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "account-app-igw"
  }
}

resource "aws_route_table" "main" {
  provider = aws.primary
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "account-app-rt"
  }
}

resource "aws_route_table_association" "main" {
  provider       = aws.primary
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group for EC2
resource "aws_security_group" "app_sg" {
  provider    = aws.primary
  name        = "account-app-sg"
  description = "Security group for account application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "account-app-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  provider = aws.primary
  name     = "account-app-ec2-role"

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

resource "aws_iam_role_policy_attachment" "ec2_admin_policy" {
  provider   = aws.primary
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  provider = aws.primary
  name     = "account-app-ec2-profile"
  role     = aws_iam_role.ec2_role.name
}

# Key Pair for EC2
resource "aws_key_pair" "ec2_key" {
  provider   = aws.primary
  key_name   = "account-app-ec2-key"
  public_key = file("${path.module}/account-app-ec2-key.pem.pub")
}

# EC2 Instance
resource "aws_instance" "account_app" {
  provider                    = aws.primary
  ami                         = "ami-0ae2c887094315bed"
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.ec2_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  subnet_id                   = aws_subnet.main.id
  associate_public_ip_address = true

  user_data_base64 = base64encode(templatefile("${path.module}/user_data.sh", {
    app_code = base64encode(file("${path.module}/src/app.py"))
  }))

  tags = {
    Name = "account-app-ec2"
  }
}

