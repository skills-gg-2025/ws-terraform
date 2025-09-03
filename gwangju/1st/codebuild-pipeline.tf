# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild" {
  name = "gj2025-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.codebuild.name
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline" {
  name = "gj2025-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_admin" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.codepipeline.name
}

# Security Group for NLB in App VPC
resource "aws_security_group" "app_nlb" {
  name        = "gj2025-app-nlb-sg"
  description = "Security group for NLB in App VPC"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "gj2025-app-nlb-sg"
  }
}

# Security Group for NLB in Hub VPC
resource "aws_security_group" "hub_nlb" {
  name        = "gj2025-hub-nlb-sg"
  description = "Security group for NLB in Hub VPC"
  vpc_id      = aws_vpc.hub.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "gj2025-hub-nlb-sg"
  }
}