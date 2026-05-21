# ─── Extractor ───────────────────────────────────────────────────────────────
# Reads raw documents from S3, extracts text, saves to text bucket.

resource "aws_iam_role" "extractor" {
  name = "${var.extractor_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "extractor" {
  name = "${var.extractor_lambda_name}-policy"
  role = aws_iam_role.extractor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.extractor_lambda_name}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.ingestion_pdf_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.ingestion_text_formattted_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.ingestion_pdf.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "extractor_vpc" {
  role       = aws_iam_role.extractor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── Splitter ────────────────────────────────────────────────────────────────
# Reads extracted text from S3, splits into chunks, sends batches to SQS.

resource "aws_iam_role" "splitter" {
  name = "${var.splitter_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "splitter" {
  name = "${var.splitter_lambda_name}-policy"
  role = aws_iam_role.splitter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.splitter_lambda_name}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.ingestion_text_formattted_bucket.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.ingestion_text.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.embedder_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "splitter_vpc" {
  role       = aws_iam_role.splitter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── Embedder ─────────────────────────────────────────────────────────────────
# Receives chunk batches from SQS, calls Bedrock for embeddings, indexes to OpenSearch.

resource "aws_iam_role" "embedder" {
  name = "${var.embedder_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "embedder" {
  name = "${var.embedder_lambda_name}-policy"
  role = aws_iam_role.embedder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.embedder_lambda_name}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.embedder_queue.arn
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${var.vectorization_model_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.prefix}/opensearch/${var.opensearch_collection_name}/endpoint"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "embedder_vpc" {
  role       = aws_iam_role.embedder.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ─── Query ────────────────────────────────────────────────────────────────────
# Receives user questions via API Gateway, searches OpenSearch, generates answers via Bedrock.

resource "aws_iam_role" "query" {
  name = "${var.query_lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "query" {
  name = "${var.query_lambda_name}-policy"
  role = aws_iam_role.query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.query_lambda_name}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${var.vectorization_model_id}",
          "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${var.query_model_id}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.prefix}/opensearch/${var.opensearch_collection_name}/endpoint"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "query_vpc" {
  role       = aws_iam_role.query.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
