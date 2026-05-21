resource "aws_ssm_parameter" "ingestion_pdf_bucket" {
  name  = "/${var.prefix}/s3/ingestion-bucket"
  type  = "String"
  value = aws_s3_bucket.ingestion_pdf_bucket.bucket
}