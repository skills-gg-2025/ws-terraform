output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.governance_ec2.id
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.tag_restore_function.function_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_log_group.name
}