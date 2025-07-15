provider "aws" {
  region = "us-west-1"
}

# Default VPC 데이터 소스
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key Pair
resource "aws_key_pair" "xxe_key" {
  key_name   = "xxe-key"
  public_key = file("${path.module}/src/xxe-key.pub")

  tags = {
    Name = "xxe-key"
  }
}

# Security Group for EC2
resource "aws_security_group" "xxe_server_sg" {
  name        = "xxe-server-sg"
  description = "Security group for XXE server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    security_groups = [ aws_security_group.alb_sg.id ]
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
    Name = "xxe-server-sg"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

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
    Name = "xxe-alb-sg"
  }
}

# EC2 Instance
resource "aws_instance" "xxe_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.xxe_key.key_name

  vpc_security_group_ids = [aws_security_group.xxe_server_sg.id]

  user_data = templatefile("${path.module}/user_data.sh", {
    app_py_content      = file("${path.module}/src/app.py")
    requirements_content = file("${path.module}/src/requirements.txt")
  })

  tags = {
    Name = "xxe-server"
  }
}

# Application Load Balancer
resource "aws_lb" "xxe_alb" {
  name               = "xxe-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "xxe-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "xxe_tg" {
  name     = "xxe-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name = "xxe-tg"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "xxe_tg_attachment" {
  target_group_arn = aws_lb_target_group.xxe_tg.arn
  target_id        = aws_instance.xxe_server.id
  port             = 5000
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "xxe_protection" {
  name  = "xxe-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # XXE 공격 방어 규칙 - DOCTYPE 차단
  rule {
    name     = "BlockDOCTYPE"
    priority = 1

    action {
      block {
        custom_response {
          response_code = 403
          custom_response_body_key = "forbidden_message"
        }
      }
    }

    statement {
      byte_match_statement {
        search_string = "<!doctype"
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "LOWERCASE"
        }
        positional_constraint = "CONTAINS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockDOCTYPE"
      sampled_requests_enabled   = true
    }
  }

  # XXE 공격 방어 규칙 - ENTITY 차단
  rule {
    name     = "BlockENTITY"
    priority = 2

    action {
      block {
        custom_response {
          response_code = 403
          custom_response_body_key = "forbidden_message"
        }
      }
    }

    statement {
      byte_match_statement {
        search_string = "<!entity"
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "LOWERCASE"
        }
        positional_constraint = "CONTAINS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockENTITY"
      sampled_requests_enabled   = true
    }
  }

  # 파일 접근 차단
  rule {
    name     = "BlockFileAccess"
    priority = 3

    action {
      block {
        custom_response {
          response_code = 403
          custom_response_body_key = "forbidden_message"
        }
      }
    }

    statement {
      byte_match_statement {
        search_string = "file://"
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "LOWERCASE"
        }
        positional_constraint = "CONTAINS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockFileAccess"
      sampled_requests_enabled   = true
    }
  }

  # 메타데이터 접근 차단
  rule {
    name     = "BlockMetadataAccess"
    priority = 4

    action {
      block {
        custom_response {
          response_code = 403
          custom_response_body_key = "forbidden_message"
        }
      }
    }

    statement {
      byte_match_statement {
        search_string = "169.254.169.254"
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "LOWERCASE"
        }
        positional_constraint = "CONTAINS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockMetadataAccess"
      sampled_requests_enabled   = true
    }
  }

  # Custom response body
  custom_response_body {
    key          = "forbidden_message"
    content      = "403 Forbidden error"
    content_type = "TEXT_PLAIN"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "XXEProtectionACL"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "xxe-protection-acl"
  }
}

# WAF Association with ALB
resource "aws_wafv2_web_acl_association" "xxe_waf_association" {
  resource_arn = aws_lb.xxe_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.xxe_protection.arn
}

# ALB Listener
resource "aws_lb_listener" "xxe_listener" {
  load_balancer_arn = aws_lb.xxe_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.xxe_tg.arn
  }
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.xxe_alb.dns_name
}

output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.xxe_server.public_ip
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.xxe_protection.arn
}