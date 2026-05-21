output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "lambda_embedder_role_arn" {
  value = aws_iam_role.embedder.arn
}

output "lambda_embedder_role_name" {
  value = aws_iam_role.embedder.name
}

output "lambda_query_role_arn" {
  value = aws_iam_role.query.arn
}

output "lambda_query_role_name" {
  value = aws_iam_role.query.name
}

output "documents_bucket_name" {
  value = aws_s3_bucket.ingestion_pdf_bucket.bucket
}

output "opensearch_endpoint_id" {
  value = aws_opensearchserverless_vpc_endpoint.opensearch.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.api.id
}

output "cognito_user_pool_endpoint" {
  value = aws_cognito_user_pool.main.endpoint
}