# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "ws25-ecs-cluster"

  configuration {
    managed_storage_configuration {
      kms_key_id = aws_kms_key.rds_key.arn
    }
  }

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = {
    Name = "ws25-ecs-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "green_logs" {
  name              = "/ws25/logs/green"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds_key.arn
}

resource "aws_cloudwatch_log_group" "red_logs" {
  name              = "/ws25/logs/red"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds_key.arn
}

resource "aws_cloudwatch_log_group" "firelens_logs" {
  name              = "/ecs/firelens"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds_key.arn
}

# ECS Capacity Provider for EC2
resource "aws_ecs_capacity_provider" "ec2" {
  name = "ws25-asg-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

    managed_scaling {
      maximum_scaling_step_size = 3
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 3
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# Launch Template for ECS EC2 instances
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ws25-ecs-lt"
  image_id      = data.aws_ami.ecs_al2023_optimized.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.bastion_key.key_name

  vpc_security_group_ids = [aws_security_group.ecs_ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ws25-ecs-container-green"
    }
  }
}

# Auto Scaling Group for ECS EC2
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ws25-ecs-asg"
  vpc_zone_identifier = [aws_subnet.app_pri_a.id, aws_subnet.app_pri_b.id, aws_subnet.app_pri_c.id]
  target_group_arns   = []
  health_check_type   = "EC2"

  min_size         = 1
  max_size         = 3
  desired_capacity = 3

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ws25-ecs-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Security Group for ECS EC2 (Green)
resource "aws_security_group" "ecs_ec2_sg" {
  name_prefix = "ws25-ecs-ec2-"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ws25-ecs-ec2-sg"
  }
}

# Security Group for ECS Fargate (Red)
resource "aws_security_group" "ecs_fargate_sg" {
  name_prefix = "ws25-ecs-fargate-"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ws25-ecs-fargate-sg"
  }
}

# IAM Role for ECS Instance
resource "aws_iam_role" "ecs_instance_role" {
  name = "ws25-ecs-instance-role"

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

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ws25-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ws25-ecs-task-execution-role"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "ws25-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.rds_key.arn
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ws25-ecs-task-role"

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

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ws25-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "${aws_s3_bucket.fluent_config.arn}",
          "${aws_s3_bucket.fluent_config.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Task Definition for Green Application
resource "aws_ecs_task_definition" "green" {
  family                   = "ws25-ecs-green-taskdef"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "1024"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "green"
      image     = "${aws_ecr_repository.green.repository_url}:v1.0.0"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_USER::"
        },
        {
          name      = "DB_PASSWD"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_PASSWD::"
        },
        {
          name      = "DB_URL"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_URL::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awsfirelens"
      }

      dependsOn = [
        {
          containerName = "log_router"
          condition     = "START"
        }
      ]
    },
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"
      essential = false

      firelensConfiguration = {
        type = "fluentbit"
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.firelens_logs.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "firelens"
        }
      }

      environment = [
        {
          name  = "aws_fluent_bit_init_s3_1"
          value = "arn:aws:s3:::${aws_s3_bucket.fluent_config.bucket}/fluent-bit-green.conf"
        }
      ]
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# Task Definition for Red Application
resource "aws_ecs_task_definition" "red" {
  family                   = "ws25-ecs-red-taskdef"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "red"
      image     = "${aws_ecr_repository.red.repository_url}:v1.0.0"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_USER::"
        },
        {
          name      = "DB_PASSWD"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_PASSWD::"
        },
        {
          name      = "DB_URL"
          valueFrom = "${aws_secretsmanager_secret.db_secret.arn}:DB_URL::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awsfirelens"
      }

      dependsOn = [
        {
          containerName = "log_router"
          condition     = "START"
        }
      ]
    },
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"
      essential = false

      firelensConfiguration = {
        type = "fluentbit"
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.firelens_logs.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "firelens"
        }
      }

      environment = [
        {
          name  = "aws_fluent_bit_init_s3_1"
          value = "arn:aws:s3:::${aws_s3_bucket.fluent_config.bucket}/fluent-bit-red.conf"
        }
      ]
    }
  ])

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# ECS Service for Green Application
resource "aws_ecs_service" "green" {
  name            = "ws25-ecs-green"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.green.arn
  desired_count   = 3

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.green_primary.arn
    container_name   = "green"
    container_port   = 8080
  }


  availability_zone_rebalancing = "ENABLED"

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  depends_on = [terraform_data.green_100, aws_autoscaling_group.ecs_asg]
}

# ECS Service for Red Application
resource "aws_ecs_service" "red" {
  name            = "ws25-ecs-red"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.red.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.app_pri_a.id, aws_subnet.app_pri_b.id, aws_subnet.app_pri_c.id]
    security_groups = [aws_security_group.ecs_fargate_sg.id]
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.red_primary.arn
    container_name   = "red"
    container_port   = 8080
  }

  availability_zone_rebalancing = "ENABLED"

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  depends_on = [terraform_data.red_100]
}

# Data source for ECS optimized AMI
data "aws_ami" "ecs_al2023_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-ecs-hvm-*-x86_64"]
  }
}
