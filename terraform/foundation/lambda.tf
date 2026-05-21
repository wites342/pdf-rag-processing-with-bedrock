resource "aws_lambda_function" "extractor" {
  function_name = var.extractor_lambda_name
  description   = "Extracts text from uploaded documents and saves to S3 for downstream processing"

  filename         = "${path.module}/build/extractor.zip"
  source_code_hash = filebase64sha256("${path.module}/build/extractor.zip")

  runtime     = "python3.14"
  handler     = "extractor.lambda_handler"
  timeout     = 300
  memory_size = 512

  role = aws_iam_role.extractor.arn

  vpc_config {
    subnet_ids         = [for s in aws_subnet.private : s.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      TEXT_OUTPUT_BUCKET = aws_s3_bucket.ingestion_text_formattted_bucket.id
    }
  }
}

resource "aws_lambda_function" "splitter" {
  function_name = var.splitter_lambda_name
  description   = "Splits extracted text into chunk batches and dispatches them to SQS for embedding"

  filename         = "${path.module}/build/splitter.zip"
  source_code_hash = filebase64sha256("${path.module}/build/splitter.zip")

  runtime     = "python3.14"
  handler     = "splitter.lambda_handler"
  timeout     = 300
  memory_size = 512

  role = aws_iam_role.splitter.arn

  vpc_config {
    subnet_ids         = [for s in aws_subnet.private : s.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      CHUNK_PROCESSING_QUEUE_URL = aws_sqs_queue.embedder_queue.url
    }
  }
}

resource "aws_lambda_function" "embedder" {
  function_name = var.embedder_lambda_name
  description   = "Generates embeddings for text chunks in parallel and indexes them into OpenSearch"

  filename         = "${path.module}/build/embedder.zip"
  source_code_hash = filebase64sha256("${path.module}/build/embedder.zip")

  runtime     = "python3.14"
  handler     = "embedder.lambda_handler"
  timeout     = 300
  memory_size = 512

  role = aws_iam_role.embedder.arn

  vpc_config {
    subnet_ids         = [for s in aws_subnet.private : s.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SSM_OPENSEARCH_COLLECTION_ENDPOINT_HOLDER = "/${var.prefix}/opensearch/${var.opensearch_collection_name}/endpoint"
      OPENSEARCH_INDEX_NAME                     = var.index_name
      VECTORIZATION_MODEL_ID                    = var.vectorization_model_id
    }
  }
}

resource "aws_lambda_function" "query" {
  function_name = var.query_lambda_name
  description   = "Queries the OpenSearch index for relevant documents and generates responses using Bedrock"

  filename         = "${path.module}/build/query.zip"
  source_code_hash = filebase64sha256("${path.module}/build/query.zip")

  runtime     = "python3.14"
  handler     = "query.lambda_handler"
  timeout     = 300
  memory_size = 512

  role = aws_iam_role.query.arn

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = [for s in aws_subnet.private : s.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SSM_OPENSEARCH_COLLECTION_ENDPOINT_HOLDER = "/${var.prefix}/opensearch/${var.opensearch_collection_name}/endpoint"
      OPENSEARCH_INDEX_NAME                     = var.index_name
      VECTORIZATION_MODEL_ID                    = var.vectorization_model_id
      QUERY_MODEL_ID                            = var.query_model_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.query_lambda]
}
