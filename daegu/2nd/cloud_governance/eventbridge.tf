resource "aws_cloudwatch_event_rule" "tag_change_rule" {
  name        = "ec2-TagChange-rule"
  description = "Capture EC2 tag deletions via CloudTrail"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    detail-type   = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName   = ["DeleteTags"]
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.tag_change_rule.name
  target_id = "TagRestoreLambdaTarget"
  arn       = aws_lambda_function.tag_restore_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tag_restore_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tag_change_rule.arn
}