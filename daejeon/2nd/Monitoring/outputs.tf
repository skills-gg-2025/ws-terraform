output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.app_alb.dns_name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "cloudwatch_dashboard_url" {
  description = "The URL of the CloudWatch Dashboard"
  value       = "https://ap-northeast-1.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=${aws_cloudwatch_dashboard.app_dashboard.dashboard_name}"
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.app_cluster.name
}