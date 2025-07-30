output "consumer_alb_dns" {
  description = "DNS name of the Consumer ALB"
  value       = aws_lb.consumer_external.dns_name
}

output "service_alb_dns" {
  description = "DNS name of the Service ALB"
  value       = aws_lb.service_internal.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion host"
  value       = aws_eip.bastion.public_ip
}

output "vpc_lattice_service_id" {
  description = "VPC Lattice Service ID"
  value       = aws_vpclattice_service.app.id
}

output "vpc_lattice_service_arn" {
  description = "VPC Lattice Service ARN"
  value       = aws_vpclattice_service.app.arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.app_table.name
}

output "consumer_vpc_id" {
  description = "Consumer VPC ID"
  value       = aws_vpc.consumer.id
}

output "service_vpc_id" {
  description = "Service VPC ID"
  value       = aws_vpc.service.id
}
