# ECS Cluster
resource "aws_ecs_cluster" "skills_log_cluster" {
  name = "skills-log-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "skills-log-cluster"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "skills_log_ecs_sg" {
  name        = "skills-log-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.skills_log_vpc.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.skills_log_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-log-ecs-sg"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "skills-log-ecs-task-execution-role"

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

# Additional policy for CloudWatch Logs and ECR
resource "aws_iam_role_policy" "ecs_task_execution_additional_policy" {
  name = "skills-log-ecs-task-execution-additional-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "skills-log-ecs-task-role"

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
  name = "skills-log-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "skills_log_app_td" {
  family                   = "skills-log-app-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.skills_app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      essential = true
      logDriver = "awsfirelens"
      logConfiguration = {
        logDriver = "awsfirelens"
        options   = {}
      }
      dependsOn = [
        {
          containerName = "log_router"
          condition     = "START"
        }
      ]
    },
    {
      name  = "log_router"
      image = "${aws_ecr_repository.skills_firelens.repository_url}:latest"
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          config-file-type  = "file"
          config-file-value = "/fluent-bit/conf/extra.conf"
        }
      }
      essential = true
      logDriver = "awslogs"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.skills_app_logs.name
          awslogs-region        = "eu-west-1"
          awslogs-stream-prefix = "firelens"
        }
      }
    }
  ])

  tags = {
    Name = "skills-log-app-td"
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.skills_log_cluster.id
  task_definition = aws_ecs_task_definition.skills_log_app_td.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.skills_log_priv_a.id, aws_subnet.skills_log_priv_b.id]
    security_groups = [aws_security_group.skills_log_ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.skills_log_app_tg.arn
    container_name   = "app"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.skills_log_alb_listener,
    aws_iam_role_policy.ecs_task_execution_additional_policy
  ]

  tags = {
    Name = "app"
  }
}
