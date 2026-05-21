resource "aws_cloudwatch_log_group" "query_lambda" {
  name              = "/aws/lambda/${var.query_lambda_name}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "apigw_access" {
  name              = "/aws/apigateway/${var.apigw_name}/access"
  retention_in_days = 30
}
