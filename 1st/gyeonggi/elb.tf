# Hub VPC Network Load Balancer
resource "aws_lb" "hub_nlb" {
  name               = "ws25-hub-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.hub_pub_a.id, aws_subnet.hub_pub_c.id]

  tags = {
    Name = "ws25-hub-nlb"
  }
}

# Hub NLB Target Group
resource "aws_lb_target_group" "hub_nlb_tg" {
  name        = "ws25-hub-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.hub_vpc.id

  health_check {
    protocol = "TCP"
  }

  tags = {
    Name = "ws25-hub-nlb-tg"
  }
}

# Hub NLB Listener
resource "aws_lb_listener" "hub_nlb_listener" {
  load_balancer_arn = aws_lb.hub_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hub_nlb_tg.arn
  }
}

# Application VPC Network Load Balancer
resource "aws_lb" "app_nlb" {
  name               = "ws25-app-nlb"
  internal           = true
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id            = aws_subnet.app_pri_a.id
    private_ipv4_address = "10.200.20.100"
  }

  subnet_mapping {
    subnet_id            = aws_subnet.app_pri_b.id
    private_ipv4_address = "10.200.21.100"
  }

  subnet_mapping {
    subnet_id            = aws_subnet.app_pri_c.id
    private_ipv4_address = "10.200.22.100"
  }

  tags = {
    Name = "ws25-app-nlb"
  }
}

# App NLB Target Group
resource "aws_lb_target_group" "app_nlb_tg" {
  name        = "ws25-app-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.app_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 2
  }

  tags = {
    Name = "ws25-app-nlb-tg"
  }
}

# App NLB Listener
resource "aws_lb_listener" "app_nlb_listener" {
  load_balancer_arn = aws_lb.app_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_nlb_tg.arn
  }
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "ws25-app-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.app_pri_a.id, aws_subnet.app_pri_b.id, aws_subnet.app_pri_c.id]

  tags = {
    Name = "ws25-app-alb"
  }
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "ws25-alb-sg"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app_vpc.cidr_block, aws_vpc.hub_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ws25-alb-sg"
  }
}

# ALB Target Groups for Green and Red
resource "aws_lb_target_group" "green_primary" {
  name                 = "ws25-green-primary-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.app_vpc.id
  deregistration_delay = 10

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
    Name = "ws25-green-primary-tg"
  }
}

resource "aws_lb_target_group" "green_sub" {
  name                 = "ws25-green-sub-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.app_vpc.id
  deregistration_delay = 10

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
    Name = "ws25-green-sub-tg"
  }
}

resource "aws_lb_target_group" "red_primary" {
  name                 = "ws25-red-primary-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.app_vpc.id
  deregistration_delay = 10

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
    Name = "ws25-red-primary-tg"
  }
}

resource "aws_lb_target_group" "red_sub" {
  name                 = "ws25-red-sub-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.app_vpc.id
  deregistration_delay = 10

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
    Name = "ws25-red-sub-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "app_alb_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<center><h1>404 Not Found</h1></center>"
      status_code  = "404"
    }
  }
}

# ALB Listener Rules
resource "aws_lb_listener_rule" "green_rule" {
  listener_arn = aws_lb_listener.app_alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_primary.arn
  }

  condition {
    path_pattern {
      values = ["/green"]
    }
  }
}

resource "aws_lb_listener_rule" "red_rule" {
  listener_arn = aws_lb_listener.app_alb_listener.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.red_primary.arn
  }

  condition {
    path_pattern {
      values = ["/red"]
    }
  }
}

resource "aws_lb_listener_rule" "health_rule" {
  listener_arn = aws_lb_listener.app_alb_listener.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_primary.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }
}

resource "aws_lb_listener_rule" "error_rule" {
  listener_arn = aws_lb_listener.app_alb_listener.arn
  priority     = 300

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<center><h1>500 Internal Server Error</h1></center>"
      status_code  = "500"
    }
  }

  condition {
    path_pattern {
      values = ["/error"]
    }
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "app_nlb_to_alb" {
  target_group_arn = aws_lb_target_group.app_nlb_tg.arn
  target_id        = aws_lb.app_alb.arn
  port             = 80

  depends_on = [aws_lb_listener.app_alb_listener]
}

# Hub NLB targets (App NLB IPs)
resource "aws_lb_target_group_attachment" "hub_nlb_target_a" {
  target_group_arn  = aws_lb_target_group.hub_nlb_tg.arn
  target_id         = data.aws_network_interface.app_nlb_eni_a.private_ip
  port              = 80
  availability_zone = "ap-northeast-2a"
}

resource "aws_lb_target_group_attachment" "hub_nlb_target_b" {
  target_group_arn  = aws_lb_target_group.hub_nlb_tg.arn
  target_id         = data.aws_network_interface.app_nlb_eni_b.private_ip
  port              = 80
  availability_zone = "ap-northeast-2c"
}

resource "aws_lb_target_group_attachment" "hub_nlb_target_c" {
  target_group_arn  = aws_lb_target_group.hub_nlb_tg.arn
  target_id         = data.aws_network_interface.app_nlb_eni_c.private_ip
  port              = 80
  availability_zone = "ap-northeast-2a"
}

# Data source to get App NLB ENI IPs
data "aws_network_interfaces" "app_nlb_enis" {
  filter {
    name   = "description"
    values = ["ELB ${aws_lb.app_nlb.arn_suffix}"]
  }

  depends_on = [aws_lb.app_nlb]
}

data "aws_network_interface" "app_nlb_eni_a" {
  id = data.aws_network_interfaces.app_nlb_enis.ids[0]
}

data "aws_network_interface" "app_nlb_eni_b" {
  id = data.aws_network_interfaces.app_nlb_enis.ids[1]
}

data "aws_network_interface" "app_nlb_eni_c" {
  id = data.aws_network_interfaces.app_nlb_enis.ids[2]
}