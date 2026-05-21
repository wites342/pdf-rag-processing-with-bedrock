import io
import json
import logging
import os
import boto3
import pypdf

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3", region_name=os.environ["AWS_REGION"])


def extract_text(bucket, key):
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()

    if key.endswith(".pdf"):
        reader = pypdf.PdfReader(io.BytesIO(body))
        logger.info("PDF has %d pages: %s", len(reader.pages), key)
        return " ".join(page.extract_text() for page in reader.pages)

    return body.decode("utf-8")


def save_text(text, key, output_bucket):
    text_key = key.rsplit(".", 1)[0] + ".txt"
    s3.put_object(Bucket=output_bucket, Key=text_key, Body=text.encode("utf-8"))


def parse_s3_origin(sqs_record):
    body = json.loads(sqs_record["body"])
    if "Records" not in body:
        # S3 sends a test event when the notification is first configured
        logger.info("Skipping non-S3-event message: %s", body.get("Event", "unknown"))
        return None, None
    s3_record = body["Records"][0]["s3"]
    return s3_record["bucket"]["name"], s3_record["object"]["key"]


def lambda_handler(event, context):
    output_bucket = os.environ["TEXT_OUTPUT_BUCKET"]
    bucket, key = parse_s3_origin(event["Records"][0])

    if not bucket:
        return {"statusCode": 200, "body": "Skipped test notification"}

    logger.info("Extracting text from s3://%s/%s", bucket, key)

    text = extract_text(bucket, key)
    save_text(text, key, output_bucket)

    logger.info("Successfully extracted and saved text from %s (%d chars)", key, len(text))
    return {"statusCode": 200, "body": f"Extracted and saved text from {key}"}
