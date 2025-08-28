# Internal ALB Security Group
resource "aws_security_group" "wsk_int_alb_sg" {
  name        = "wsk-int-alb-sg"
  description = "wsk-int-alb-sg"
  vpc_id      = aws_vpc.wsk_app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.wsk_app.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsk-int-alb-sg"
  }
}

# Internal ALB
resource "aws_lb" "wsk_int_alb" {
  name               = "wsk-int-alb"
  internal           = true
  load_balancer_type = "application"
  subnets            = [aws_subnet.wsk_app_priv_a.id, aws_subnet.wsk_app_priv_b.id]
  security_groups    = [aws_security_group.wsk_int_alb_sg.id]

  tags = {
    Name = "wsk-int-alb"
  }

  depends_on = [null_resource.deploy_k8s]
}

# Nginx Proxy Target Group
resource "aws_lb_target_group" "nginx_tg" {
  name        = "nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wsk_app.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/health"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "nginx-tg"
  }

  depends_on = [null_resource.deploy_k8s]
}

# Internal ALB Listener
resource "aws_lb_listener" "wsk_int_alb_listener" {
  load_balancer_arn = aws_lb.wsk_int_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

# Internal NLB
resource "aws_lb" "wsk_int_nlb" {
  name               = "wsk-int-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.wsk_app_priv_a.id, aws_subnet.wsk_app_priv_b.id]

  tags = {
    Name = "wsk-int-nlb"
  }

  depends_on = [null_resource.deploy_k8s]
}

# Internal NLB Target Group
resource "aws_lb_target_group" "wsk_int_nlb_tg" {
  name        = "wsk-int-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.wsk_app.id
  target_type = "alb"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/health"
    timeout             = 10
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "wsk-int-nlb-tg"
  }
}

# Attach wsk-int-alb to Internal NLB Target Group
resource "aws_lb_target_group_attachment" "int_nlb_alb_attachment" {
  target_group_arn = aws_lb_target_group.wsk_int_nlb_tg.arn
  target_id        = aws_lb.wsk_int_alb.arn
  port             = 80

  depends_on = [aws_lb_listener.wsk_int_alb_listener]
}

# Internal NLB Listener
resource "aws_lb_listener" "wsk_int_nlb_listener" {
  load_balancer_arn = aws_lb.wsk_int_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wsk_int_nlb_tg.arn
  }
}

# VPC Endpoint Service
resource "aws_vpc_endpoint_service" "wsk_vpce_svc_intnlb" {
  network_load_balancer_arns = [aws_lb.wsk_int_nlb.arn]
  acceptance_required        = false

  tags = {
    Name = "wsk-vpce-svc-intnlb"
  }
}

# VPC Endpoint Security Group
resource "aws_security_group" "wsk_vpce_sg" {
  name        = "wsk-vpce-sg"
  description = "wsk-vpce-sg"
  vpc_id      = aws_vpc.wsk_hub.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.wsk_hub.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsk-vpce-sg"
  }
}

# VPC Endpoint
resource "aws_vpc_endpoint" "wsk_vpce_intnlb" {
  vpc_id              = aws_vpc.wsk_hub.id
  service_name        = aws_vpc_endpoint_service.wsk_vpce_svc_intnlb.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.wsk_hub_pub_a.id, aws_subnet.wsk_hub_pub_b.id]
  security_group_ids  = [aws_security_group.wsk_vpce_sg.id]

  tags = {
    Name = "wsk-vpce-intnlb"
  }
}

# External NLB
resource "aws_lb" "wsk_ext_nlb" {
  name               = "wsk-ext-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.wsk_hub_pub_a.id, aws_subnet.wsk_hub_pub_b.id]

  tags = {
    Name = "wsk-ext-nlb"
  }
}

# External NLB Target Group
resource "aws_lb_target_group" "wsk_tg_extnlb" {
  name        = "wsk-tg-extnlb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.wsk_hub.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 10
    unhealthy_threshold = 2
  }

  tags = {
    Name = "wsk-tg-extnlb"
  }
}

# Get VPC Endpoint network interface private IPs
data "aws_network_interface" "vpce_eni" {
  count = 2
  id    = tolist(aws_vpc_endpoint.wsk_vpce_intnlb.network_interface_ids)[count.index]
}

# Attach VPC Endpoint IPs to External NLB Target Group
resource "aws_lb_target_group_attachment" "ext_nlb_vpce_attachment" {
  count            = 2
  target_group_arn = aws_lb_target_group.wsk_tg_extnlb.arn
  target_id        = data.aws_network_interface.vpce_eni[count.index].private_ip
  port             = 80
}

# External NLB Listener
resource "aws_lb_listener" "wsk_ext_nlb_listener" {
  load_balancer_arn = aws_lb.wsk_ext_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wsk_tg_extnlb.arn
  }
}

# Nginx Proxy Security Group
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-proxy-sg"
  description = "nginx-proxy-sg"
  vpc_id      = aws_vpc.wsk_app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.wsk_app.cidr_block]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.wsk_hub.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-proxy-sg"
  }
}

# IAM Role for Nginx Proxy
resource "aws_iam_role" "nginx_proxy_role" {
  name = "nginx-proxy-role"

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

resource "aws_iam_role_policy" "nginx_proxy_policy" {
  name = "nginx-proxy-policy"
  role = aws_iam_role.nginx_proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "nginx_proxy_profile" {
  name = "nginx-proxy-profile"
  role = aws_iam_role.nginx_proxy_role.name
}

# Nginx Proxy Instance
resource "aws_instance" "nginx_proxy" {
  ami                    = "ami-0ae2c887094315bed"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.wsk_app_priv_a.id
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  key_name               = "wsk-bastion-key"
  iam_instance_profile   = aws_iam_instance_profile.nginx_proxy_profile.name

  user_data = base64encode(<<-EOF
#!/bin/bash
yum update -y
yum install -y nginx awscli

# Wait for ALBs to be created
sleep 120

# Get ALB DNS names dynamically
GREEN_ALB_DNS=$(aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[?contains(LoadBalancerName, `green-alb`)].DNSName' --output text)
RED_ALB_DNS=$(aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[?contains(LoadBalancerName, `red-alb`)].DNSName' --output text)

# Create nginx config with actual ALB DNS names
cat > /etc/nginx/conf.d/proxy.conf << EOT
server {
    listen 80;
    
    location / {
        proxy_pass http://$GREEN_ALB_DNS;
        proxy_set_header Host \$host;
    }
    location /health {
        proxy_pass http://$GREEN_ALB_DNS;
        proxy_set_header Host \$host;
    }
    location /green {
        proxy_pass http://$GREEN_ALB_DNS;
        proxy_set_header Host \$host;
    }
    
    location /red {
        proxy_pass http://$RED_ALB_DNS;
        proxy_set_header Host \$host;
    }
}
EOT

systemctl start nginx
systemctl enable nginx
EOF
  )

  tags = {
    Name = "nginx-proxy"
  }

  depends_on = [null_resource.deploy_k8s]
}

# Attach Nginx instance to target group
resource "aws_lb_target_group_attachment" "nginx_attachment" {
  target_group_arn = aws_lb_target_group.nginx_tg.arn
  target_id        = aws_instance.nginx_proxy.id
  port             = 80
}