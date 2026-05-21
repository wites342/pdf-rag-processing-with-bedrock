import json
import logging
import os
import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def _get_opensearch_host():
    parameter_name = os.environ["SSM_OPENSEARCH_COLLECTION_ENDPOINT_HOLDER"]
    response = ssm_client.get_parameter(Name=parameter_name)
    return response["Parameter"]["Value"].replace("https://", "")

s3_client = boto3.client("s3", region_name=os.environ["AWS_REGION"])
bedrock_client = boto3.client("bedrock-runtime", region_name=os.environ["AWS_REGION"])
ssm_client = boto3.client("ssm", region_name=os.environ["AWS_REGION"])
OPENSEARCH_HOST = _get_opensearch_host()
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
        connection_class=RequestsHttpConnection
    )

def prepare_prompt(context_chunks, question):
    prompt_path = os.path.join(os.path.dirname(__file__), "prompt.txt")
    with open(prompt_path) as f:
        prompt_template = f.read()

    return prompt_template.format(
        context="\n\n".join(context_chunks),
        question=question
    )

def search_opensearch(client, embedding):
    index = os.environ["OPENSEARCH_INDEX_NAME"]
    response = client.search(
        index=index,
        body={
            "size": 5,
            "query": {
                "knn": {
                    "embedding": {
                        "vector": embedding,
                        "k": 5
                    }
                }
            }
        }
    )
    hits = response["hits"]["hits"]
    logger.info("kNN returned %d hits", len(hits))
    return hits

def generate_embedding_with_bedrock(question, model_id) -> list:
    response = bedrock_client.invoke_model(
        modelId=model_id,
        body=json.dumps({"inputText": question})
    )
    return json.loads(response["body"].read())["embedding"]

def call_claude(prompt, query_model) -> str:
    response = bedrock_client.invoke_model(
        modelId=query_model,
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        })
    )
    return json.loads(response["body"].read())["content"][0]["text"]

def lambda_handler(event, context):
    body = json.loads(event["body"])

    vectorization_model = os.environ.get("VECTORIZATION_MODEL_ID")
    query_model = os.environ.get("QUERY_MODEL_ID")
    question = body["question"]

    logger.info("Question: %s", question)

    opensearch_client = get_opensearch_client()

    question_embedding = generate_embedding_with_bedrock(question, vectorization_model)
    hits = search_opensearch(opensearch_client, question_embedding)

    chunks = [hit["_source"]["text"] for hit in hits]
    sources = list({hit["_source"]["source"] for hit in hits})

    prompt = prepare_prompt(chunks, question)
    answer = call_claude(prompt, query_model)

    logger.info("Successfully answered question using %d chunks from %d source(s)", len(chunks), len(sources))
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "answer": answer,
            "sources": sources
        })
    }
