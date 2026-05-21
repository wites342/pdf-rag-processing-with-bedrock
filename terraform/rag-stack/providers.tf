provider "opensearch" {
  url                   = aws_opensearchserverless_collection.vectors.collection_endpoint
  aws_region            = data.aws_region.current.region
  aws_signature_service = "aoss"
  sign_aws_requests     = true
  healthcheck           = false
}