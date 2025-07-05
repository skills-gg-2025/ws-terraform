# Secrets Manager for DB credentials
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "ws25/secret/key"
  description             = "Database credentials for Green and Red applications"
  kms_key_id              = aws_kms_key.rds_key.arn
  recovery_window_in_days = 0

  tags = {
    Name = "ws25-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    DB_USER   = var.username
    DB_PASSWD = var.password
    DB_URL    = "${aws_rds_cluster.aurora_cluster.endpoint}:10101"
  })
}