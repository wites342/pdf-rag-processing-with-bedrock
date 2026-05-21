resource "aws_apigatewayv2_api" "main" {
  name          = var.apigw_name
  protocol_type = "HTTP"
  description   = "RAG query endpoint"

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["POST"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

resource "aws_apigatewayv2_integration" "query" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.apigw_name}-cognito"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.api.id]
    issuer   = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

resource "aws_apigatewayv2_route" "query" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /query"
  target             = "integrations/${aws_apigatewayv2_integration.query.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      responseLatency  = "$context.responseLatency"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      authorizerError  = "$context.authorizer.error"
    })
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}