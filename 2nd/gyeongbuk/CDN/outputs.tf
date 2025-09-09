# Output important values
output "cloudfront_distribution_id" {
  description = "CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront Distribution Domain Name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "s3_bucket_kr_name" {
  description = "S3 Bucket name for Korea region"
  value       = aws_s3_bucket.kr_static.id
}

output "s3_bucket_us_name" {
  description = "S3 Bucket name for US region"
  value       = aws_s3_bucket.us_static.id
}

output "mrap_alias" {
  description = "S3 Multi-Region Access Point Alias"
  value       = aws_s3control_multi_region_access_point.mrap.alias
}

output "mrap_domain_name" {
  description = "S3 Multi-Region Access Point Domain Name"
  value       = aws_s3control_multi_region_access_point.mrap.domain_name
}

output "bastion_public_ip" {
  description = "Bastion server public IP"
  value       = aws_eip.bastion.public_ip
}

output "bastion_private_key_path" {
  description = "Path to bastion private key"
  value       = "${path.module}/src/mrap-bastion-key"
}

output "lambda_function_kr_name" {
  description = "Lambda function name for KR invalidation"
  value       = aws_lambda_function.invalidation_kr.function_name
}

output "lambda_function_us_name" {
  description = "Lambda function name for US invalidation"
  value       = aws_lambda_function.invalidation_us.function_name
}

output "cloudfront_function_name" {
  description = "CloudFront Function name"
  value       = aws_cloudfront_function.viewer_request.name
}

output "lambda_edge_function_name" {
  description = "Lambda@Edge Function name"
  value       = aws_lambda_function.edge_function.function_name
}
