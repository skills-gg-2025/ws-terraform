resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/tag-restore-func"
  retention_in_days = 14
}