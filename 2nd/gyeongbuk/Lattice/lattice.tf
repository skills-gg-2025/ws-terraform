# VPC Lattice Service Network
resource "aws_vpclattice_service_network" "main" {
  name      = "skills-app-service-network"
  auth_type = "NONE"

  tags = {
    Name = "skills-app-service-network"
  }
}

# VPC Lattice Service
resource "aws_vpclattice_service" "app" {
  name      = "skills-app-service"
  auth_type = "NONE"

  tags = {
    Name = "skills-app-service"
  }
}

# VPC Lattice Target Group
resource "aws_vpclattice_target_group" "alb" {
  name = "skills-alb-tg"
  type = "ALB"

  config {
    port           = 80
    protocol       = "HTTP"
    vpc_identifier = aws_vpc.service.id
  }

  tags = {
    Name = "skills-alb-tg"
  }
}

# VPC Lattice Service Network Service Association
resource "aws_vpclattice_service_network_service_association" "app" {
  service_identifier         = aws_vpclattice_service.app.id
  service_network_identifier = aws_vpclattice_service_network.main.id

  tags = {
    Name = "skills-app-service-association"
  }
}

# VPC Lattice Service Network VPC Association for Consumer VPC
resource "aws_vpclattice_service_network_vpc_association" "consumer" {
  vpc_identifier             = aws_vpc.consumer.id
  service_network_identifier = aws_vpclattice_service_network.main.id

  tags = {
    Name = "skills-consumer-vpc-association"
  }
}

# VPC Lattice Service Network VPC Association for Service VPC
resource "aws_vpclattice_service_network_vpc_association" "service" {
  vpc_identifier             = aws_vpc.service.id
  service_network_identifier = aws_vpclattice_service_network.main.id

  tags = {
    Name = "skills-service-vpc-association"
  }
}

# VPC Lattice Service Listener
resource "aws_vpclattice_listener" "app" {
  name               = "skills-app-listener"
  protocol           = "HTTP"
  service_identifier = aws_vpclattice_service.app.id

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.alb.id
        weight                  = 100
      }
    }
  }

  tags = {
    Name = "skills-app-listener"
  }
}

# Target Group Attachment
resource "aws_vpclattice_target_group_attachment" "alb" {
  target_group_identifier = aws_vpclattice_target_group.alb.id

  target {
    id   = aws_lb.service_internal.arn
    port = 80
  }
}
