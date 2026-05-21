import json
import logging
import os
import boto3
from langchain_text_splitters import RecursiveCharacterTextSplitter

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CHUNK_BATCH_SIZE = 50

s3 = boto3.client("s3", region_name=os.environ["AWS_REGION"])
sqs = boto3.client("sqs", region_name=os.environ["AWS_REGION"])


def read_text_from_s3(bucket, key):
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    return body.decode("utf-8")


def split_into_chunks(text):
    chunks = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50).split_text(text)
    logger.info("Split into %d chunks", len(chunks))
    return chunks


def send_to_processing_queue(chunks, source_key, queue_url):
    for i in range(0, len(chunks), CHUNK_BATCH_SIZE):
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps({
                "source_key": source_key,
                "chunk_start_index": i,
                "chunks": chunks[i:i + CHUNK_BATCH_SIZE],
            })
        )


def parse_s3_origin(sqs_record):
    body = json.loads(sqs_record["body"])
    if "Records" not in body:
        logger.info("Skipping non-S3-event message: %s", body.get("Event", "unknown"))
        return None, None
    s3_record = body["Records"][0]["s3"]
    return s3_record["bucket"]["name"], s3_record["object"]["key"]


def lambda_handler(event, context):
    queue_url = os.environ["CHUNK_PROCESSING_QUEUE_URL"]
    bucket, key = parse_s3_origin(event["Records"][0])

    if not bucket:
        return {"statusCode": 200, "body": "Skipped test notification"}

    logger.info("Processing %s", key)

    text = read_text_from_s3(bucket, key)
    chunks = split_into_chunks(text)
    send_to_processing_queue(chunks, key, queue_url)

    logger.info("Successfully queued %d chunks from %s", len(chunks), key)
    return {"statusCode": 200, "body": f"Queued {len(chunks)} chunks from {key}"}
