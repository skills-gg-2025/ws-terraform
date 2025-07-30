# Consumer ALB Security Group
resource "aws_security_group" "consumer_alb" {
  name_prefix = "skills-consumer-alb-sg"
  vpc_id      = aws_vpc.consumer.id

  ingress {
    description = "HTTP"
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
    Name = "skills-consumer-alb-sg"
  }
}

# Consumer Server Security Group
resource "aws_security_group" "consumer_server" {
  name_prefix = "skills-consumer-server-sg"
  vpc_id      = aws_vpc.consumer.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.consumer_alb.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-consumer-server-sg"
  }
}

# Service ALB Security Group
resource "aws_security_group" "service_alb" {
  name_prefix = "skills-service-alb-sg"
  vpc_id      = aws_vpc.service.id

  ingress {
    description = "HTTP from VPC Lattice"
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
    Name = "skills-service-alb-sg"
  }
}

# App Server Security Group
resource "aws_security_group" "app_server" {
  name_prefix = "skills-app-server-sg"
  vpc_id      = aws_vpc.service.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.service_alb.id]
  }

  ingress {
    description = "SSH from Bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.consumer.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-app-server-sg"
  }
}

# Consumer External ALB
resource "aws_lb" "consumer_external" {
  name               = "skills-consumer-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.consumer_alb.id]
  subnets = [
    aws_subnet.consumer_public_a.id,
    aws_subnet.consumer_public_c.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "skills-consumer-alb"
  }
}

# Service Internal ALB
resource "aws_lb" "service_internal" {
  name               = "skills-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.service_alb.id]
  subnets = [
    aws_subnet.service_private_a.id,
    aws_subnet.service_private_c.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "skills-app-alb"
  }
}

# Consumer ALB Target Group
resource "aws_lb_target_group" "consumer" {
  name     = "skills-consumer-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.consumer.id

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
    Name = "skills-consumer-tg"
  }
}

# Service ALB Target Group
resource "aws_lb_target_group" "service" {
  name     = "skills-app-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.service.id

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
    Name = "skills-app-tg"
  }
}

# Consumer ALB Listener
resource "aws_lb_listener" "consumer" {
  load_balancer_arn = aws_lb.consumer_external.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consumer.arn
  }
}

# Service ALB Listener
resource "aws_lb_listener" "service" {
  load_balancer_arn = aws_lb.service_internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}
