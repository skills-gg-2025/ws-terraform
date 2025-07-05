# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.data_vpc.id

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
    Name = "alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "ws_data_alb" {
  name               = "ws-data-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.data_public_a.id, aws_subnet.data_public_b.id]

  tags = {
    Name = "ws-data-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "ws_data_tg" {
  name     = "ws-data-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.data_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name = "ws-data-tg"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "ws_data_app_attachment" {
  target_group_arn = aws_lb_target_group.ws_data_tg.arn
  target_id        = aws_instance.ws_data_app.id
  port             = 8080
}

# ALB Listener
resource "aws_lb_listener" "ws_data_listener" {
  load_balancer_arn = aws_lb.ws_data_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ws_data_tg.arn
  }
}