resource "aws_sqs_queue" "ingestion_pdf_dlq" {
  name                      = "${var.prefix}-rag-ingestion-pdf-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"
}

resource "aws_sqs_queue" "ingestion_pdf" {
  name                       = "${var.prefix}-rag-ingestion-pdf"
  visibility_timeout_seconds = 1800
  message_retention_seconds  = 86400 # 1 day
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_pdf_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_event_source_mapping" "ingestion_pdf" {
  event_source_arn = aws_sqs_queue.ingestion_pdf.arn
  function_name    = aws_lambda_function.extractor.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue_policy" "ingestion_pdf" {
  queue_url = aws_sqs_queue.ingestion_pdf.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.ingestion_pdf.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.ingestion_pdf_bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue" "ingestion_text_dlq" {
  name                      = "${var.prefix}-rag-ingestion-text-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"
}

resource "aws_sqs_queue" "ingestion_text" {
  name                       = "${var.prefix}-rag-ingestion-text"
  visibility_timeout_seconds = 1800
  message_retention_seconds  = 86400 # 1 day
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_text_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_event_source_mapping" "ingestion_text" {
  event_source_arn = aws_sqs_queue.ingestion_text.arn
  function_name    = aws_lambda_function.splitter.arn
  batch_size       = 1
  enabled          = true
}

resource "aws_sqs_queue_policy" "ingestion_text" {
  queue_url = aws_sqs_queue.ingestion_text.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.ingestion_text.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.ingestion_text_formattted_bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue" "embedder_queue_dlq" {
  name                      = "${var.prefix}-rag-embedder-queue-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"
}

resource "aws_sqs_queue" "embedder_queue" {
  name                       = "${var.prefix}-rag-embedder-queue"
  visibility_timeout_seconds = 1800
  message_retention_seconds  = 86400 # 1 day
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.embedder_queue_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_event_source_mapping" "embedder_queue" {
  event_source_arn = aws_sqs_queue.embedder_queue.arn
  function_name    = aws_lambda_function.embedder.arn
  batch_size       = 1
  enabled          = true
}
