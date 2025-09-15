# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description = "KMS key for RDS encryption"
  
  tags = {
    Name = "gj2025-rds-key"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/gj2025-rds-key"
  target_key_id = aws_kms_key.rds.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "gj2025-db-subnet-group"
  subnet_ids = [aws_subnet.app_data_a.id, aws_subnet.app_data_b.id]

  tags = {
    Name = "gj2025-db-subnet-group"
  }
}

# Security Group for RDS Proxy
resource "aws_security_group" "rds_proxy" {
  name        = "gj2025-rds-proxy-sg"
  description = "Security group for RDS proxy"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "192.168.0.0/16"]
  }

  tags = {
    Name = "gj2025-rds-proxy-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "gj2025-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.app.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gj2025-rds-sg"
  }
}

# RDS ingress rule from RDS Proxy
resource "aws_security_group_rule" "rds_ingress_from_proxy" {
  type                     = "ingress"
  from_port                = 3309
  to_port                  = 3309
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds_proxy.id
  security_group_id        = aws_security_group.rds.id
}

# Allow all outbound traffic for RDS Proxy
resource "aws_security_group_rule" "rds_proxy_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_proxy.id
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "gj2025-db-instance"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.rds.arn
  
  db_name  = "day1"
  username = "admin"
  password = "Skills53#$%"
  port     = 3309
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  enabled_cloudwatch_logs_exports = ["audit", "error", "general"]
  
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "gj2025-db-final-snapshot"
  
  tags = {
    Name = "gj2025-db-instance"
  }
}

# Secrets Manager Secret for RDS Proxy
resource "aws_secretsmanager_secret" "rds_proxy" {
  name = "gj2025-rds-proxy-secret-v2"
}

resource "aws_secretsmanager_secret_version" "rds_proxy" {
  secret_id = aws_secretsmanager_secret.rds_proxy.id
  secret_string = jsonencode({
    username = "admin"
    password = "Skills53#$%"
  })
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "rds_proxy" {
  name = "gj2025-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "rds_proxy" {
  name = "gj2025-rds-proxy-policy"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_proxy.arn
      }
    ]
  })
}

# RDS Proxy
resource "aws_db_proxy" "main" {
  name          = "gj2025-rds-proxy"
  engine_family = "MYSQL"
  
  auth {
    auth_scheme               = "SECRETS"
    secret_arn                = aws_secretsmanager_secret.rds_proxy.arn
    client_password_auth_type = "MYSQL_NATIVE_PASSWORD"
  }
  
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_subnet_ids         = [aws_subnet.app_data_a.id, aws_subnet.app_data_b.id]
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  require_tls            = false

  tags = {
    Name = "gj2025-rds-proxy"
  }
}

# RDS Proxy Target Group
resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name
}

# RDS Proxy Target
resource "aws_db_proxy_target" "main" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
}