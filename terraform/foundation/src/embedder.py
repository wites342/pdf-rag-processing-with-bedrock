import json
import logging
import os
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed
from opensearchpy import OpenSearch, RequestsHttpConnection, helpers
from requests_aws4auth import AWS4Auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

MAX_WORKERS = 10

# Adaptive retry lets boto3 automatically back off on Bedrock throttling
bedrock = boto3.client(
    "bedrock-runtime",
    region_name=os.environ["AWS_REGION"],
    config=Config(retries={"max_attempts": 5, "mode": "adaptive"})
)
ssm = boto3.client("ssm", region_name=os.environ["AWS_REGION"])


def _resolve_opensearch_host():
    endpoint = ssm.get_parameter(Name=os.environ["SSM_OPENSEARCH_COLLECTION_ENDPOINT_HOLDER"])["Parameter"]["Value"]
    return endpoint.replace("https://", "")

OPENSEARCH_HOST = _resolve_opensearch_host()
logger.info("Cold start: OpenSearch host resolved to %s", OPENSEARCH_HOST)


def get_opensearch_client():
    credentials = boto3.Session().get_credentials()
    auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        os.environ["AWS_REGION"],
        "aoss",
        session_token=credentials.token
    )
    return OpenSearch(
        hosts=[{"host": OPENSEARCH_HOST, "port": 443}],
        http_auth=auth,
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection,
        timeout=60,
        max_retries=3,
        retry_on_timeout=True
    )


def embed_chunk(chunk, model_id):
    response = bedrock.invoke_model(
        modelId=model_id,
        body=json.dumps({"inputText": chunk})
    )
    return json.loads(response["body"].read())["embedding"]


def embed_all_chunks(chunks, model_id):
    embeddings = {}

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_to_index = {
            executor.submit(embed_chunk, chunk, model_id): i
            for i, chunk in enumerate(chunks)
        }

        for future in as_completed(future_to_index):
            chunk_index = future_to_index[future]
            try:
                embeddings[chunk_index] = future.result()
            except Exception as e:
                logger.error("Embedding failed for chunk %d: %s", chunk_index, e)
                raise

    return [embeddings[i] for i in range(len(chunks))]


def index_chunks(client, chunks, embeddings, source_key, chunk_start_index, index_name):
    documents = [
        {
            "_index": index_name,
            "_source": {
                "text": chunk,
                "source": source_key,
                "chunk_id": chunk_start_index + i,
                "embedding": embedding,
            }
        }
        for i, (chunk, embedding) in enumerate(zip(chunks, embeddings))
    ]

    success, errors = helpers.bulk(client, documents, raise_on_error=False)

    if errors:
        logger.error("%d bulk index failures: %s", len(errors), errors)
        raise RuntimeError(f"Bulk indexing failed with {len(errors)} errors - SQS will retry")

    logger.info("Indexed %d chunks", success)


def lambda_handler(event, context):
    model_id = os.environ["VECTORIZATION_MODEL_ID"]
    index_name = os.environ["OPENSEARCH_INDEX_NAME"]

    message = json.loads(event["Records"][0]["body"])
    source_key = message["source_key"]
    chunk_start_index = message["chunk_start_index"]
    chunks = message["chunks"]

    logger.info("Processing %d chunks from %s (batch starting at %d)", len(chunks), source_key, chunk_start_index)

    client = get_opensearch_client()
    embeddings = embed_all_chunks(chunks, model_id)
    index_chunks(client, chunks, embeddings, source_key, chunk_start_index, index_name)

    logger.info("Successfully embedded and indexed %d chunks from %s (batch offset %d)", len(chunks), source_key, chunk_start_index)
    return {"statusCode": 200, "body": f"Indexed {len(chunks)} chunks from {source_key}"}
