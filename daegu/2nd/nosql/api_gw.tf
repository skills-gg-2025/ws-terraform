# API Gateway
resource "aws_api_gateway_rest_api" "chat_api" {
  name        = "chat-api"
  description = "Chat Messages API"
}

resource "aws_api_gateway_resource" "send_messages" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "send-messages"
}

resource "aws_api_gateway_resource" "get_messages" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "get-messages"
}

resource "aws_api_gateway_resource" "update_messages" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "update-messages"
}

resource "aws_api_gateway_resource" "delete_messages" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  parent_id   = aws_api_gateway_rest_api.chat_api.root_resource_id
  path_part   = "delete-messages"
}

# API Gateway 메서드들
resource "aws_api_gateway_method" "send_post" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.send_messages.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_get" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.get_messages.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "update_put" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.update_messages.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "delete_delete" {
  rest_api_id   = aws_api_gateway_rest_api.chat_api.id
  resource_id   = aws_api_gateway_resource.delete_messages.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# API Gateway 통합
resource "aws_api_gateway_integration" "send_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.send_messages.id
  http_method = aws_api_gateway_method.send_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.chat_handler.invoke_arn
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.get_messages.id
  http_method = aws_api_gateway_method.get_get.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.chat_handler.invoke_arn
}

resource "aws_api_gateway_integration" "update_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.update_messages.id
  http_method = aws_api_gateway_method.update_put.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.chat_handler.invoke_arn
}

resource "aws_api_gateway_integration" "delete_integration" {
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  resource_id = aws_api_gateway_resource.delete_messages.id
  http_method = aws_api_gateway_method.delete_delete.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.chat_handler.invoke_arn
}

# API Gateway 배포
resource "aws_api_gateway_deployment" "chat_deployment" {
  depends_on = [
    aws_api_gateway_integration.send_integration,
    aws_api_gateway_integration.get_integration,
    aws_api_gateway_integration.update_integration,
    aws_api_gateway_integration.delete_integration
  ]
  
  rest_api_id = aws_api_gateway_rest_api.chat_api.id
  stage_name  = "prod"
}