resource "aws_db_instance" "wsc2025_db_instance" {
  identifier = "wsc2025-db-instance"
  
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.medium"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  storage_encrypted    = true
  
  db_name  = "day1"
  username = "admin"
  password = "Skill53##"
  
  multi_az = true
  
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  
  tags = {
    Name = "wsc2025-db-instance"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "wsc2025-db-subnet-group"
  subnet_ids = [aws_subnet.app_db_a.id, aws_subnet.app_db_b.id]
  
  tags = {
    Name = "wsc2025-db-subnet-group"
  }
}

resource "aws_security_group" "db_sg" {
  name_prefix = "wsc2025-db-sg"
  vpc_id      = aws_vpc.app.id
  
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "wsc2025-db-sg"
  }
}