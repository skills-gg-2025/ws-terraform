// Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "moni-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.moni_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "moni-alb-sg"
  }
}

// Application Load Balancer
resource "aws_lb" "moni_alb" {
  name               = "moni-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.moni_public_a.id, aws_subnet.moni_public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "moni-alb"
  }
}

// ALB Target Group
resource "aws_lb_target_group" "moni_tg" {
  name        = "moni-target-group"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.moni_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "moni-target-group"
  }
}

// ALB Listener
resource "aws_lb_listener" "moni_listener" {
  load_balancer_arn = aws_lb.moni_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.moni_tg.arn
  }
}