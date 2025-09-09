# KMS Key for Secrets Manager and EKS encryption
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for Skills Secrets Manager and EKS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "skills-secrets-eks-kms-key"
  }
}

# KMS Key Alias
resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/skills-secrets-eks-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "skills_secrets" {
  name        = "skills-secrets"
  description = "Application Database connection environment variables"
  kms_key_id  = aws_kms_key.secrets_key.arn

  tags = {
    Name = "skills-secrets"
  }
}

# Secrets Manager Secret Version with database connection details
resource "aws_secretsmanager_secret_version" "skills_secrets_version" {
  secret_id = aws_secretsmanager_secret.skills_secrets.id
  secret_string = jsonencode({
    DB_USER   = aws_rds_cluster.skills_db_cluster.master_username
    DB_PASSWD = aws_rds_cluster.skills_db_cluster.master_password
    DB_URL    = aws_rds_cluster.skills_db_cluster.endpoint
  })
}
