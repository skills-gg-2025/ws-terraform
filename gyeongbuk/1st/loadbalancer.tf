# Internal Application Load Balancer
resource "aws_lb" "skills_alb" {
  name               = "skills-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "skills-alb"
  }
}

# ALB Target Group

# ALB Target Group - Green
resource "aws_lb_target_group" "green_tg" {
  name     = "skills-green-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.app.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "skills-green-tg"
  }
}

# ALB Target Group - Red
resource "aws_lb_target_group" "red_tg" {
  name     = "skills-red-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.app.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = {
    Name = "skills-red-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.skills_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }

  tags = {
    Name = "skills-alb-listener"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "skills-alb-sg"
  description = "Security group for Skills Internal ALB"
  vpc_id      = aws_vpc.app.id

  # HTTP access from Internal NLB
  ingress {
    description = "HTTP from Internal NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-alb-sg"
  }
}

# Internal Network Load Balancer
resource "aws_lb" "skills_internal_nlb" {
  name               = "skills-internal-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "skills-internal-nlb"
  }
}

# Internal NLB Target Group
resource "aws_lb_target_group" "internal_nlb_tg" {
  name        = "skills-internal-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = aws_vpc.app.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/health"
  }

  tags = {
    Name = "skills-internal-nlb-tg"
  }
}

# Internal NLB Listener
resource "aws_lb_listener" "internal_nlb_listener" {
  load_balancer_arn = aws_lb.skills_internal_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_nlb_tg.arn
  }

  tags = {
    Name = "skills-internal-nlb-listener"
  }
}

# Target Group Attachment - ALB to Internal NLB
resource "aws_lb_target_group_attachment" "alb_to_internal_nlb" {
  target_group_arn = aws_lb_target_group.internal_nlb_tg.id
  target_id        = aws_lb.skills_alb.arn
  port             = 80

  depends_on = [ aws_lb_listener.alb_listener ]
}

# VPC Endpoint Service for Internal NLB
resource "aws_vpc_endpoint_service" "internal_nlb_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.skills_internal_nlb.arn]

  tags = {
    Name = "skills-internal-nlb-service"
  }
}

# VPC Endpoint in Hub VPC to connect to Internal NLB
resource "aws_vpc_endpoint" "internal_nlb_endpoint" {
  vpc_id               = aws_vpc.hub.id
  service_name         = aws_vpc_endpoint_service.internal_nlb_service.service_name
  subnet_ids           = [aws_subnet.hub_subnet_a.id, aws_subnet.hub_subnet_b.id]
  vpc_endpoint_type    = "Interface"
  security_group_ids   = [aws_security_group.vpc_endpoint_nlb_sg.id]
  private_dns_enabled  = false

  tags = {
    Name = "skills-internal-nlb-endpoint"
  }
}

# Security Group for VPC Endpoint
resource "aws_security_group" "vpc_endpoint_nlb_sg" {
  name        = "skills-vpc-endpoint-nlb-sg"
  description = "Security group for VPC Endpoint to Internal NLB"
  vpc_id      = aws_vpc.hub.id

  # Allow traffic from External NLB
  ingress {
    description = "HTTP from External NLB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.hub.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-vpc-endpoint-nlb-sg"
  }
}

# External Network Load Balancer
resource "aws_lb" "skills_nlb" {
  name               = "skills-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.hub_subnet_a.id, aws_subnet.hub_subnet_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "skills-nlb"
  }
}

# External NLB Target Group
resource "aws_lb_target_group" "external_nlb_tg" {
  name        = "skills-nlb-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.hub.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
  }

  tags = {
    Name = "skills-nlb-tg"
  }
}

# External NLB Listener
resource "aws_lb_listener" "external_nlb_listener" {
  load_balancer_arn = aws_lb.skills_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_nlb_tg.arn
  }

  tags = {
    Name = "skills-nlb-listener"
  }
}

# Target Group Attachments - VPC Endpoint IPs to External NLB (AZ-a)
resource "aws_lb_target_group_attachment" "vpc_endpoint_to_external_nlb_a" {
  target_group_arn = aws_lb_target_group.external_nlb_tg.id
  target_id        = data.aws_network_interface.vpc_endpoint_eni_a.private_ip
  port             = 80

  depends_on = [aws_vpc_endpoint.internal_nlb_endpoint]
}

# Target Group Attachments - VPC Endpoint IPs to External NLB (AZ-b)
resource "aws_lb_target_group_attachment" "vpc_endpoint_to_external_nlb_b" {
  target_group_arn = aws_lb_target_group.external_nlb_tg.id
  target_id        = data.aws_network_interface.vpc_endpoint_eni_b.private_ip
  port             = 80

  depends_on = [aws_vpc_endpoint.internal_nlb_endpoint]
}

# Data source to get VPC Endpoint ENI private IP for AZ-a
data "aws_network_interface" "vpc_endpoint_eni_a" {
  id = tolist(aws_vpc_endpoint.internal_nlb_endpoint.network_interface_ids)[0]
}

# Data source to get VPC Endpoint ENI private IP for AZ-b  
data "aws_network_interface" "vpc_endpoint_eni_b" {
  id = tolist(aws_vpc_endpoint.internal_nlb_endpoint.network_interface_ids)[1]
}

resource "aws_lb_listener_rule" "alb_green_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green_tg.arn
  }
  condition {
    path_pattern {
      values = ["/green*"]
    }
  }
}

resource "aws_lb_listener_rule" "alb_red_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.red_tg.arn
  }
  condition {
    path_pattern {
      values = ["/red*"]
    }
  }
}

resource "aws_lb_listener_rule" "alb_health_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 30
  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.green_tg.arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.red_tg.arn
        weight = 50
      }
    }
  }
  condition {
    path_pattern {
      values = ["/health*"]
    }
  }
}