output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.skills_log_vpc.id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion server"
  value       = aws_instance.skills_log_bastion.public_ip
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.skills_log_alb.dns_name
}

output "ecr_app_repository_url" {
  description = "URL of the ECR repository for the application"
  value       = aws_ecr_repository.skills_app.repository_url
}

output "ecr_firelens_repository_url" {
  description = "URL of the ECR repository for Fluent Bit"
  value       = aws_ecr_repository.skills_firelens.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.skills_log_cluster.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.skills_app_logs.name
}
