# Security Group for ALB
resource "aws_security_group" "skills_log_alb_sg" {
  name        = "skills-log-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.skills_log_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "skills-log-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "skills_log_alb" {
  name               = "skills-log-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.skills_log_alb_sg.id]
  subnets            = [aws_subnet.skills_log_pub_a.id, aws_subnet.skills_log_pub_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "skills-log-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "skills_log_app_tg" {
  name        = "skills-log-app-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.skills_log_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "skills-log-app-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "skills_log_alb_listener" {
  load_balancer_arn = aws_lb.skills_log_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.skills_log_app_tg.arn
  }
}
