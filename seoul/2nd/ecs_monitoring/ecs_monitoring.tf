terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "wsi_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "wsi-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "wsi_igw" {
  vpc_id = aws_vpc.wsi_vpc.id
  tags = {
    Name = "wsi-igw"
  }
}

# Public Subnets
resource "aws_subnet" "wsi_pub_a" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "wsi-pub-a"
  }
}

resource "aws_subnet" "wsi_pub_b" {
  vpc_id                  = aws_vpc.wsi_vpc.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "wsi-pub-b"
  }
}

# Route Table
resource "aws_route_table" "wsi_public_rt" {
  vpc_id = aws_vpc.wsi_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wsi_igw.id
  }
  tags = {
    Name = "wsi-public-rt"
  }
}

resource "aws_route_table_association" "wsi_pub_a_rta" {
  subnet_id      = aws_subnet.wsi_pub_a.id
  route_table_id = aws_route_table.wsi_public_rt.id
}

resource "aws_route_table_association" "wsi_pub_b_rta" {
  subnet_id      = aws_subnet.wsi_pub_b.id
  route_table_id = aws_route_table.wsi_public_rt.id
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg"
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

resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs-sg"
  vpc_id      = aws_vpc.wsi_vpc.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg"
  vpc_id      = aws_vpc.wsi_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
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

# IAM Role
resource "aws_iam_role" "wsi_ecs_role" {
  name = "wsi-ecs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.wsi_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_full_access" {
  role       = aws_iam_role.wsi_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "python_error" {
  name              = "python/error"
  retention_in_days = 7
}

# ECR Repository
resource "aws_ecr_repository" "python_app" {
  name = "python-app"
}

# ECS Cluster
resource "aws_ecs_cluster" "wsi_ecs_cluster" {
  name = "wsi-ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "python_task" {
  family                   = "python-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.wsi_ecs_role.arn
  task_role_arn           = aws_iam_role.wsi_ecs_role.arn

  container_definitions = jsonencode([
    {
      name  = "python-container"
      image = "${aws_ecr_repository.python_app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.python_error.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  
  depends_on = [null_resource.docker_build_on_bastion]
}

# ALB
resource "aws_lb" "wsi_alb" {
  name               = "wsi-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.wsi_pub_a.id, aws_subnet.wsi_pub_b.id]
}

# Target Group
resource "aws_lb_target_group" "wsi_target_group" {
  name        = "wsi-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.wsi_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# ALB Listener
resource "aws_lb_listener" "wsi_listener" {
  load_balancer_arn = aws_lb.wsi_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wsi_target_group.arn
  }
}

# ECS Service
resource "aws_ecs_service" "python_service" {
  name            = "python-service"
  cluster         = aws_ecs_cluster.wsi_ecs_cluster.id
  task_definition = aws_ecs_task_definition.python_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.wsi_pub_a.id, aws_subnet.wsi_pub_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wsi_target_group.arn
    container_name   = "python-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.wsi_listener, aws_ecs_task_definition.python_task]
}

# SNS Topic
resource "aws_sns_topic" "server_error_sns" {
  name = "server-error-sns"
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.server_error_sns.arn
  protocol  = "email"
  endpoint  = "skills+001@chob.app"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_overload_alarm" {
  alarm_name          = "cpu-overload-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm monitors ECS service CPU utilization"

  dimensions = {
    ServiceName = aws_ecs_service.python_service.name
    ClusterName = aws_ecs_cluster.wsi_ecs_cluster.name
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization" {
  alarm_name          = "ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm monitors ECS service memory utilization"

  dimensions = {
    ServiceName = aws_ecs_service.python_service.name
    ClusterName = aws_ecs_cluster.wsi_ecs_cluster.name
  }
}

# Bastion Host IAM Role
resource "aws_iam_role" "bastion_role" {
  name = "bastion-role"
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

resource "aws_iam_role_policy_attachment" "bastion_admin_access" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Key Pair
resource "aws_key_pair" "wsi_bastion_key" {
  key_name   = "wsi-bastion-key"
  public_key = file("wsi-bastion-key.pub")
}

# Bastion Host
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "local_file" "dockerfile" {
  content = <<-EOF
FROM python:3.9-slim
WORKDIR /app
COPY main.py .
RUN pip install flask
EXPOSE 80
CMD ["python", "main.py"]
EOF
  filename = "${path.module}/src/Dockerfile"
}

resource "aws_instance" "wsi_bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.wsi_pub_a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name
  key_name               = aws_key_pair.wsi_bastion_key.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y jq docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    mkdir -p /tmp/python-app/
    ./aws/install
  EOF

  tags = {
    Name = "wsi-bastion"
  }
}

# Docker build on Bastion Host
resource "null_resource" "docker_build_on_bastion" {
  depends_on = [aws_instance.wsi_bastion, aws_ecr_repository.python_app]
  
  connection {
    type        = "ssh"
    host        = aws_instance.wsi_bastion.public_ip
    user        = "ec2-user"
    private_key = file("wsi-bastion-key.pem")
    timeout     = "5m"
  }
  
  provisioner "file" {
    source      = "src/"
    destination = "/tmp/python-app"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y docker",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "cd /tmp/python-app",
      "aws ecr get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin ${aws_ecr_repository.python_app.repository_url}",
      "sudo docker build -t python-app .",
      "sudo docker tag python-app:latest ${aws_ecr_repository.python_app.repository_url}:latest",
      "sudo docker push ${aws_ecr_repository.python_app.repository_url}:latest"
    ]
  }
}

# Outputs
output "bastion_public_ip" {
  value = aws_instance.wsi_bastion.public_ip
  description = "Public IP of the Bastion Host"
}

output "ssh_command" {
  value = "ssh -i wsi-bastion-key.pem ec2-user@${aws_instance.wsi_bastion.public_ip}"
  description = "SSH command to connect to Bastion Host"
}

output "alb_dns_name" {
  value = aws_lb.wsi_alb.dns_name
  description = "DNS name of the Application Load Balancer"
}