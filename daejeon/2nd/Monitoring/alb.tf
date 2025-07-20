# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "wsi-alb-sg"
  description = "Allow inbound traffic to ALB"
  vpc_id      = aws_vpc.wsi_vpc.id

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
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "wsi-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.wsi_pub_sn_a.id, aws_subnet.wsi_pub_sn_c.id]

  enable_deletion_protection = false

  tags = {
    Name = "wsi-app-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name        = "wsi-app-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wsi_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthcheck"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
  }
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}