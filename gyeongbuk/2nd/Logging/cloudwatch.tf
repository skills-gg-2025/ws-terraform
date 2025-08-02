# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "skills_app_logs" {
  name              = "/skills/app"
  retention_in_days = 7

  tags = {
    Name = "skills-app-logs"
  }
}
