variable "vpc_availability_zones" {
  description = "List of availability zones for VPC subnets"
  type        = list(string)
}

variable "prefix" {
  type = string
}

variable "extractor_lambda_name" {
  description = "Full function name for the extractor Lambda"
  type        = string
}

variable "splitter_lambda_name" {
  description = "Full function name for the splitter Lambda"
  type        = string
}

variable "embedder_lambda_name" {
  description = "Full function name for the embedder Lambda"
  type        = string
}

variable "query_lambda_name" {
  description = "Full function name for the query Lambda"
  type        = string
}

variable "vectorization_model_id" {
  description = "Model used for vectorization"
  type = string
}

variable "query_model_id" {
  description = "Model used for querying"
  type = string
}

variable "ingestion_s3_bucket_name" {
  description = "S3 bucket name for ingestion"
  type        = string
}

variable "ingestion_upload_principal_arns" {
  description = "IAM ARNs allowed to upload documents to the ingestion S3 bucket (e.g. CI role, developer role)"
  type        = list(string)
}

variable "index_name" {
  description = "Name of the OpenSearch index"
  type        = string
}

variable "opensearch_collection_name" {
  description = "Name of the vector collection"
  type        = string
}

variable "apigw_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "cors_allow_origins" {
  description = "Allowed origins for API Gateway CORS (restrict to known frontend origins in production)"
  type        = list(string)
  default     = ["*"]
}

variable "embedding_types" {
  description = "List of embedding types to generate"
  type        = list(string)
  default     = ["binary", "float"]
}

variable "admin_email" {
  description = "Email of the initial admin user in Cognito"
  type        = string
}

variable "admin_password" {
  description = "Password for the initial admin user in Cognito"
  type        = string
  sensitive   = true
}

