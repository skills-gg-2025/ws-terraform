# Lambda 함수
resource "aws_lambda_function" "chat_handler" {
  filename         = "lambda_function.zip"
  function_name    = "ChatMessageHandler"
  role            = aws_iam_role.lambda.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  
  depends_on = [data.archive_file.lambda_zip]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source {
    content = templatefile("${path.module}/lambda_function.py", {
      table_name = aws_dynamodb_table.chat_messages.name
    })
    filename = "lambda_function.py"
  }
}

# Lambda 권한
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.chat_api.execution_arn}/*/*"
}