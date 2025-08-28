# KMS Key outputs
output "kms_key_id" {
  description = "KMS Key ID"
  value       = aws_kms_key.wsk_key.key_id
}

output "kms_key_arn" {
  description = "KMS Key ARN"
  value       = aws_kms_key.wsk_key.arn
}

# RDS outputs
output "rds_cluster_endpoint" {
  description = "RDS Instance Endpoint"
  value       = aws_db_instance.wsk_rds_cluster.endpoint
}

output "rds_cluster_port" {
  description = "RDS Instance Port"
  value       = aws_db_instance.wsk_rds_cluster.port
}

# Secrets Manager outputs
output "rds_credentials_secret_arn" {
  description = "RDS Credentials Secret ARN"
  value       = aws_db_instance.wsk_rds_cluster.master_user_secret[0].secret_arn
}

output "db_url_secret_arn" {
  description = "DB URL Secret ARN"
  value       = aws_secretsmanager_secret.db_url.arn
}