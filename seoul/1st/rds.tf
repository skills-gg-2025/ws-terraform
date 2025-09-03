# DB Subnet Group
resource "aws_db_subnet_group" "wsk_db_subnet_group" {
  name       = "wsk-db-subnet-group"
  subnet_ids = [aws_subnet.wsk_app_db_a.id, aws_subnet.wsk_app_db_b.id]

  tags = {
    Name = "wsk-db-subnet-group"
  }
}

# Security Group for RDS
resource "aws_security_group" "wsk_rds_sg" {
  name        = "wsk-rds-sg"
  description = "wsk-rds-sg"
  vpc_id      = aws_vpc.wsk_app.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.76.10.100/32"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.88.3.0/24"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.88.4.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsk-rds-sg"
  }
}



# Random suffix for secret name
resource "random_string" "db_url_suffix" {
  length  = 3
  special = false
  upper   = false
}

# Secrets Manager secret for DB URL
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "wsk-db-url-${random_string.db_url_suffix.result}"
  description             = "Database URL for applications"
  kms_key_id              = aws_kms_key.wsk_key.arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = jsonencode({
    db_url = "${aws_db_instance.wsk_rds_cluster.endpoint}"
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "wsk_rds_cluster" {
  identifier                = "wsk-rds-cluster"
  engine                    = "mysql"
  engine_version            = "8.0.42"
  instance_class            = "db.t3.large"
  allocated_storage         = 20
  max_allocated_storage     = 100
  storage_type              = "gp3"
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.wsk_key.arn
  
  db_name  = "day1"
  username = "wsk${var.student_number}"
  manage_master_user_password = true
  master_user_secret_kms_key_id = aws_kms_key.wsk_key.arn
  
  db_subnet_group_name   = aws_db_subnet_group.wsk_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.wsk_rds_sg.id]
  
  backup_retention_period = 30
  backup_window          = "15:00-18:00"
  maintenance_window     = "sun:18:00-sun:19:00"
  
  enabled_cloudwatch_logs_exports = [
    "audit",
    "error",
    "general",
    "iam-db-auth-error",
    "slowquery"
  ]
  
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  
  deletion_protection = true
  skip_final_snapshot = false
  final_snapshot_identifier = "wsk-rds-cluster-final-snapshot"
  
  multi_az = true
  
  tags = {
    Name = "wsk-rds-cluster"
  }

  depends_on = [aws_kms_key.wsk_key]
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "wsk-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Automated Backup Replication to us-east-1
resource "aws_db_instance_automated_backups_replication" "wsk_rds_backup_replication" {
  source_db_instance_arn = aws_db_instance.wsk_rds_cluster.arn
  kms_key_id            = aws_kms_replica_key.wsk_key_us_east_1.arn

  provider = aws.us_east_1
}

# Initialize Database Tables
resource "null_resource" "init_database" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("wsk-bastion-key.pem")
    host        = aws_eip.wsk_bastion_eip.public_ip
    port        = 2202
  }

  provisioner "file" {
    source      = "src/day1_table_v1.sql"
    destination = "/home/ec2-user/day1_table_v1.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for RDS to be ready...'",
      "sleep 60",
      "echo 'Getting RDS credentials from Secrets Manager...'",
      "RDS_SECRET_ARN='${aws_db_instance.wsk_rds_cluster.master_user_secret[0].secret_arn}'",
      "DB_ENDPOINT='${aws_db_instance.wsk_rds_cluster.endpoint}'",
      "DB_PORT='${aws_db_instance.wsk_rds_cluster.port}'",
      "echo 'Retrieving database credentials...'",
      "DB_CREDS=$(aws secretsmanager get-secret-value --secret-id $RDS_SECRET_ARN --region ap-northeast-2 --query SecretString --output text)",
      "DB_USER=$(echo $DB_CREDS | jq -r '.username')",
      "DB_PASS=$(echo $DB_CREDS | jq -r '.password')",
      "echo 'Connecting to database and creating tables...'",
      "mysql -h $DB_ENDPOINT -P $DB_PORT -u $DB_USER -p$DB_PASS day1< /home/ec2-user/day1_table_v1.sql",
      "echo 'Database initialization completed successfully!'"
    ]
  }

  depends_on = [
    aws_db_instance.wsk_rds_cluster,
    aws_instance.wsk_bastion
  ]
}