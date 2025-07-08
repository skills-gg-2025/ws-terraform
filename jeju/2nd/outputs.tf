output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.file_storage.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.work_lambda.function_name
}

output "step_functions_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.step_workflow.arn
}

output "application_table_name" {
  description = "Name of the application DynamoDB table"
  value       = aws_dynamodb_table.application_table.name
}

output "data_table_name" {
  description = "Name of the data DynamoDB table"
  value       = aws_dynamodb_table.data_table.name
}