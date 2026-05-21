module "foundtion" {
    source = "./foundation"

    prefix                 = "future-solutions-dev"
    vpc_availability_zones = ["eu-west-2a", "eu-west-2b"]

    extractor_lambda_name  = "future-solutions-dev-rag-extractor"
    splitter_lambda_name   = "future-solutions-dev-rag-splitter"
    embedder_lambda_name   = "future-solutions-dev-rag-embedder"
    query_lambda_name      = "future-solutions-dev-rag-query"

    vectorization_model_id = "amazon.titan-embed-text-v2:0"
    query_model_id         = "anthropic.claude-sonnet-4-6"

    apigw_name                 = "rag-ingestion-api"
    opensearch_collection_name = "rag-ingestion-vectors"
    index_name                 = "documents"

    ingestion_s3_bucket_name = "rag-ingestion-bucket"

    ingestion_upload_principal_arns = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/admin",
    ]

    admin_email    = var.admin_email
    admin_password = var.admin_password
}

module "rag_stack" {
    source = "./rag-stack"

    prefix                     = "future-solutions-dev"
    opensearch_collection_name = "rag-ingestion-vectors"
    index_name                 = "documents"

    lambda_embedder_role_arn  = module.foundtion.lambda_embedder_role_arn
    lambda_embedder_role_name = module.foundtion.lambda_embedder_role_name
    lambda_query_role_arn     = module.foundtion.lambda_query_role_arn
    lambda_query_role_name    = module.foundtion.lambda_query_role_name
    opensearch_endpoint_id    = module.foundtion.opensearch_endpoint_id

    opensearch_admin_arns = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    ]
}
