output "dev_vpc_id" {
  description = "ID of the Dev VPC"
  value       = aws_vpc.dev_vpc.id
}

output "prod_vpc_id" {
  description = "ID of the Prod VPC"
  value       = aws_vpc.prod_vpc.id
}

output "dev_cluster_endpoint" {
  description = "Endpoint for Dev EKS control plane"
  value       = aws_eks_cluster.dev_cluster.endpoint
}

output "prod_cluster_endpoint" {
  description = "Endpoint for Prod EKS control plane"
  value       = aws_eks_cluster.prod_cluster.endpoint
}

output "dev_cluster_name" {
  description = "Name of the Dev EKS cluster"
  value       = aws_eks_cluster.dev_cluster.name
}

output "prod_cluster_name" {
  description = "Name of the Prod EKS cluster"
  value       = aws_eks_cluster.prod_cluster.name
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "ecr_dev_repository_url" {
  description = "URL of the Dev ECR repository"
  value       = aws_ecr_repository.product_dev.repository_url
}

output "ecr_prod_repository_url" {
  description = "URL of the Prod ECR repository"
  value       = aws_ecr_repository.product_prod.repository_url
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github_actions_role.arn
}

output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection between dev and prod"
  value       = aws_vpc_peering_connection.dev_prod_peering.id
}

output "vpc_peering_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection.dev_prod_peering.accept_status
}
