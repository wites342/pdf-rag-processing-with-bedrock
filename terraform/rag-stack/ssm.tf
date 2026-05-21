resource "aws_ssm_parameter" "ingestion_collection_endpoint" {
  name  = "/${var.prefix}/opensearch/${var.opensearch_collection_name}/endpoint"
  type  = "String"
  value = aws_opensearchserverless_collection.vectors.collection_endpoint
}