variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "opensearch_collection_name" {
  description = "Name of the vector collection"
  type        = string
}

variable "prefix" {
  type = string
}

variable "lambda_embedder_role_arn" {
  description = "ARN of the IAM role for embedder Lambda"
  type        = string
}

variable "lambda_embedder_role_name" {
  description = "Name of the IAM role for embedder Lambda"
  type        = string
}

variable "lambda_query_role_arn" {
  description = "ARN of the IAM role for query Lambda"
  type        = string
}

variable "lambda_query_role_name" {
  description = "Name of the IAM role for query Lambda"
  type        = string
}

variable "opensearch_admin_arns" {
  description = "IAM ARNs granted admin-level data access to OpenSearch (e.g. CI role, developer role)"
  type        = list(string)
  default     = []
}

variable "opensearch_endpoint_id" {
  description = "ID of the OpenSearch VPC endpoint"
  type        = string
}

variable "index_name" {
  description = "Name of the OpenSearch index"
  type        = string
}