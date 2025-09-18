output "s3_bucket_name" {
  value = aws_s3_bucket.sensitive_data.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.masking_function.function_name
}

output "macie_job_name" {
  value = aws_macie2_classification_job.sensor_job.name
}