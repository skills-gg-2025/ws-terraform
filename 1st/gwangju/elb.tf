# Data source to get existing ALB created by EKS Ingress
data "aws_lbs" "existing_albs" {
  tags = {
    "elbv2.k8s.aws/cluster" = "gj2025-eks-cluster"
  }
}

data "aws_lb" "existing_alb" {
  count = length(data.aws_lbs.existing_albs.arns) > 0 ? 1 : 0
  arn = tolist(data.aws_lbs.existing_albs.arns)[0]
  depends_on = [null_resource.eks_deploy]
}

# Security Group for Internal NLB
resource "aws_security_group" "internal_nlb" {
  name        = "gj2025-internal-nlb-sg"
  description = "Security group for internal NLB"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gj2025-internal-nlb-sg"
  }
}

# Security Group for VPC Endpoint
resource "aws_security_group" "vpc_endpoint" {
  name        = "gj2025-vpc-endpoint-sg"
  description = "Security group for VPC endpoint"
  vpc_id      = aws_vpc.hub.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gj2025-vpc-endpoint-sg"
  }
}

# Internal NLB Target Group (ALB type)
resource "aws_lb_target_group" "internal_nlb_tg" {
  name        = "gj2025-internal-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.app.id
  target_type = "alb"

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
    Name = "gj2025-internal-nlb-tg"
  }
}

# Internal NLB Target Group Attachment
resource "aws_lb_target_group_attachment" "internal_nlb_tg_attachment" {
  count            = length(data.aws_lb.existing_alb) > 0 ? 1 : 0
  target_group_arn = aws_lb_target_group.internal_nlb_tg.arn
  target_id        = data.aws_lb.existing_alb[0].arn
  port             = 80
}

# Internal NLB
resource "aws_lb" "internal_nlb" {
  name               = "gj2025-app-internal-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "gj2025-app-internal-nlb"
  }
}

# Internal NLB Listener
resource "aws_lb_listener" "internal_nlb_listener" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internal_nlb_tg.arn
  }
}

# VPC Endpoint Service
resource "aws_vpc_endpoint_service" "app_service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.internal_nlb.arn]

  tags = {
    Name = "gj2025-app-endpoint-service"
  }
}

# VPC Endpoint
resource "aws_vpc_endpoint" "app_endpoint" {
  vpc_id              = aws_vpc.hub.id
  service_name        = aws_vpc_endpoint_service.app_service.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.hub_private_a.id, aws_subnet.hub_private_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = false

  tags = {
    Name = "gj2025-app-vpc-endpoint"
  }
}

# External NLB Target Group (IP type)
resource "aws_lb_target_group" "external_nlb_tg" {
  name        = "gj2025-external-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.hub.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "gj2025-external-nlb-tg"
  }
}

# Data source to get all VPC Endpoint ENI private IPs (fixed count for 2 AZs)
data "aws_network_interface" "vpc_endpoint_enis" {
  count = 2
  id    = tolist(aws_vpc_endpoint.app_endpoint.network_interface_ids)[count.index]
}

# External NLB Target Group Attachments for all VPC Endpoint ENIs
resource "aws_lb_target_group_attachment" "external_nlb_tg_attachments" {
  count            = 2
  target_group_arn = aws_lb_target_group.external_nlb_tg.arn
  target_id        = data.aws_network_interface.vpc_endpoint_enis[count.index].private_ip
  port             = 80
}

# External NLB
resource "aws_lb" "external_nlb" {
  name               = "gj2025-app-external-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.hub_public_a.id, aws_subnet.hub_public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "gj2025-app-external-nlb"
  }
}

# External NLB Listener
resource "aws_lb_listener" "external_nlb_listener" {
  load_balancer_arn = aws_lb.external_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_nlb_tg.arn
  }
}

# ===== ArgoCD External NLB Configuration =====

# Data source to get ArgoCD Internal NLB
data "aws_lb" "argo_internal_nlb" {
  name = "gj2025-argo-internal-nlb"
  depends_on = [null_resource.eks_deploy]
}

# Data source to get ArgoCD Internal NLB ENI information
data "aws_network_interface" "argo_internal_nlb_enis" {
  count = 2
  filter {
    name   = "description"
    values = ["ELB ${data.aws_lb.argo_internal_nlb.arn_suffix}"]
  }
  filter {
    name   = "subnet-id"
    values = [tolist(data.aws_lb.argo_internal_nlb.subnets)[count.index]]
  }
}

# ArgoCD External NLB Target Group
resource "aws_lb_target_group" "argo_external_nlb_tg" {
  name        = "gj2025-argo-external-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.hub.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "gj2025-argo-external-nlb-tg"
  }
}

# ArgoCD External NLB Target Group Attachments
resource "aws_lb_target_group_attachment" "argo_external_nlb_tg_attachments" {
  count             = 2
  target_group_arn  = aws_lb_target_group.argo_external_nlb_tg.arn
  target_id         = data.aws_network_interface.argo_internal_nlb_enis[count.index].private_ip
  port              = 80
  availability_zone = data.aws_network_interface.argo_internal_nlb_enis[count.index].availability_zone
}

# ArgoCD External NLB
resource "aws_lb" "argo_external_nlb" {
  name               = "gj2025-argo-external-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.hub_public_a.id, aws_subnet.hub_public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "gj2025-argo-external-nlb"
  }
}

# ArgoCD External NLB Listener
resource "aws_lb_listener" "argo_external_nlb_listener" {
  load_balancer_arn = aws_lb.argo_external_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.argo_external_nlb_tg.arn
  }
}