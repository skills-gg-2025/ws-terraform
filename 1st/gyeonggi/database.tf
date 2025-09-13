# KMS Key for RDS encryption
resource "aws_kms_key" "rds_key" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.ap-northeast-2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "ws25-kms"
  }
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/ws25-kms"
  target_key_id = aws_kms_key.rds_key.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora_subnet_group" {
  name       = "ws25-aurora-subnet-group"
  subnet_ids = [aws_subnet.app_db_a.id, aws_subnet.app_db_c.id]

  tags = {
    Name = "ws25-aurora-subnet-group"
  }
}

# Security Group for Aurora
resource "aws_security_group" "aurora_sg" {
  name_prefix = "ws25-aurora-sg"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port       = 10101
    to_port         = 10101
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id, aws_security_group.ecs_ec2_sg.id, aws_security_group.ecs_fargate_sg.id]
  }

  tags = {
    Name = "ws25-aurora-sg"
  }
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier              = "ws25-rdb-cluster"
  engine                          = "aurora-mysql"
  engine_version                  = "8.0.mysql_aurora.3.08.2"
  database_name                   = "day1"
  master_username                 = var.username
  master_password                 = var.password
  port                            = 10101
  backup_retention_period         = 34
  backtrack_window                = 10800
  db_subnet_group_name            = aws_db_subnet_group.aurora_subnet_group.name
  vpc_security_group_ids          = [aws_security_group.aurora_sg.id]
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.rds_key.arn
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "instance"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_key.arn
  skip_final_snapshot             = true

  tags = {
    Name = "ws25-rdb-cluster"
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "aurora_instance_writer" {
  identifier         = "ws25-aurora-writer"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version
  availability_zone  = "ap-northeast-2a"

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_key.arn

  tags = {
    Name = "ws25-aurora-writer"
  }
}

resource "aws_rds_cluster_instance" "aurora_instance_reader" {
  identifier         = "ws25-aurora-reader"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version
  availability_zone  = "ap-northeast-2c"

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds_key.arn

  tags = {
    Name = "ws25-aurora-reader"
  }
}