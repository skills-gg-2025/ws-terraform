output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.account_table.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.conflict_resolver.function_name
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.account_app.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.account_app.id
}

output "api_endpoint" {
  description = "API endpoint URL"
  value       = "http://${aws_instance.account_app.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to EC2 instance"
  value       = "ssh -i account-app-ec2-key.pem ec2-user@${aws_instance.account_app.public_ip}"
}