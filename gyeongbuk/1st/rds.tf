# DB Subnet Group
resource "aws_db_subnet_group" "skills_db_subnet_group" {
  name       = "skills-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]

  tags = {
    Name = "skills-db-subnet-group"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "skills-rds-sg"
  description = "Security group for Skills RDS Aurora MySQL"
  vpc_id      = aws_vpc.app.id

  # MySQL port access from VPC
  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.app.cidr_block, aws_vpc.hub.cidr_block]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-rds-sg"
  }
}

# RDS Aurora MySQL Cluster
resource "aws_rds_cluster" "skills_db_cluster" {
  cluster_identifier           = "skills-db-cluster"
  engine                       = "aurora-mysql"
  engine_version               = "8.0.mysql_aurora.3.08.2"
  database_name                = "day1"
  master_username              = "admin"
  master_password              = "Skill53##"
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Enable logging
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  # Enable backtracking
  backtrack_window = 72

  # Storage encryption (기본 암호화 사용)
  storage_encrypted = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.skills_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Skip final snapshot for easier cleanup during development
  skip_final_snapshot = true

  # Enable deletion protection for production
  deletion_protection = false

  tags = {
    Name = "skills-db-cluster"
  }
}

# RDS Aurora MySQL Cluster Instances
resource "aws_rds_cluster_instance" "skills_db_instance" {
  count              = 2
  identifier         = "skills-db-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.skills_db_cluster.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.skills_db_cluster.engine
  engine_version     = aws_rds_cluster.skills_db_cluster.engine_version

  # Enable monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn

  tags = {
    Name = "skills-db-instance-${count.index + 1}"
  }
}



# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring_role" {
  name = "skills-rds-monitoring-role"

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

  tags = {
    Name = "skills-rds-monitoring-role"
  }
}

# Attach the RDS Enhanced Monitoring policy
resource "aws_iam_role_policy_attachment" "rds_monitoring_policy" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}