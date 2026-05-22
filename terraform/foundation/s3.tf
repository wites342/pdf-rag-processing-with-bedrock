resource "aws_s3_bucket" "ingestion_pdf_bucket" {
  bucket = "${var.prefix}-ingestion-pdf-${data.aws_caller_identity.current.account_id}"

  force_destroy = true 
}

resource "aws_s3_bucket_versioning" "ingestion_pdf_bucket" {
  bucket = aws_s3_bucket.ingestion_pdf_bucket.id
  versioning_configuration {
    status = "Suspended" # To minimize costs, we can suspend versioning.
                         # If you want to enable it, change this to "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ingestion_pdf_bucket" {
  bucket = aws_s3_bucket.ingestion_pdf_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "ingestion_pdf_bucket" {
  bucket                  = aws_s3_bucket.ingestion_pdf_bucket.id
  block_public_acls       = "true"
  block_public_policy     = "true"
  ignore_public_acls      = "true"
  restrict_public_buckets = "true"
}

resource "aws_s3_bucket_policy" "ingestion_pdf_bucket" {
  bucket = aws_s3_bucket.ingestion_pdf_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIngestionUploads"
        Effect = "Allow"
        Principal = {
          AWS = var.ingestion_upload_principal_arns
        }
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.ingestion_pdf_bucket.arn}/*"
      },
      {
        Sid    = "AllowExtractorRead"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.extractor.arn
        }
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.ingestion_pdf_bucket.arn}/*"
      },
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.ingestion_pdf_bucket.arn,
          "${aws_s3_bucket.ingestion_pdf_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.ingestion_pdf_bucket]
}

resource "aws_s3_bucket_notification" "ingestion_pdf_bucket" {
  bucket = aws_s3_bucket.ingestion_pdf_bucket.id

  queue {
    queue_arn = aws_sqs_queue.ingestion_pdf.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.ingestion_pdf]
}

resource "aws_s3_bucket" "ingestion_text_formattted_bucket" {
  bucket = "${var.prefix}-ingestion-text-formatted-${data.aws_caller_identity.current.account_id}"

  force_destroy = true
}

resource "aws_s3_bucket_versioning" "ingestion_text_formattted_bucket" {
  bucket = aws_s3_bucket.ingestion_text_formattted_bucket.id
  versioning_configuration {
    status = "Suspended" # To minimize costs, we can suspend versioning.
                         # If you want to enable it, change this to "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ingestion_text_formattted_bucket" {
  bucket = aws_s3_bucket.ingestion_text_formattted_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "ingestion_text_formattted_bucket" {
  bucket                  = aws_s3_bucket.ingestion_text_formattted_bucket.id
  block_public_acls       = "true"
  block_public_policy     = "true"
  ignore_public_acls      = "true"
  restrict_public_buckets = "true"
}

resource "aws_s3_bucket_notification" "ingestion_text_formattted_bucket" {
  bucket = aws_s3_bucket.ingestion_text_formattted_bucket.id

  queue {
    queue_arn = aws_sqs_queue.ingestion_text.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.ingestion_text]
}