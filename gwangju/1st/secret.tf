# Secrets Manager Secret for EKS Catalog
resource "aws_secretsmanager_secret" "eks_catalog" {
  name = "gj2025-eks-cluster-catalog-secret"
}

resource "aws_secretsmanager_secret_version" "eks_catalog" {
  secret_id = aws_secretsmanager_secret.eks_catalog.id
  secret_string = jsonencode({
    DB_USER     = "admin"
    DB_PASSWD = "Skills53#$%"
    DB_URL      = aws_db_proxy.main.endpoint
  })
}