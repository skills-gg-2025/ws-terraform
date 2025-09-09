output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.web_cdn.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for DRM content"
  value       = aws_s3_bucket.drm_bucket.id
}

output "lambda_function_name" {
  description = "Lambda@Edge function name"
  value       = aws_lambda_function.drm_function.function_name
}

output "cloudfront_function_name" {
  description = "CloudFront function name"
  value       = aws_cloudfront_function.web_cdn_function.name
}