
resource "aws_opensearchserverless_collection" "vectors" {
  name        = var.opensearch_collection_name
  type        = "VECTORSEARCH"
  description = "Vector store for RAG documents"

  tags = {
    Name = var.opensearch_collection_name
  }

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data
  ]
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.prefix}-encryption"
  type        = "encryption"
  description = "Encryption policy for vector collection"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.opensearch_collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.prefix}-network"
  type        = "network"
  description = "VPC access for Lambdas + public access for Terraform management"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${var.opensearch_collection_name}"]
        }
      ]
      SourceVPCEs = [var.opensearch_endpoint_id]
      SourceServices = ["bedrock.amazonaws.com"]
    },
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_iam_role_policy" "embedder_opensearch" {
  name = "${var.prefix}-embedder-opensearch"
  role = var.lambda_embedder_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = aws_opensearchserverless_collection.vectors.arn
    }]
  })
}

resource "aws_iam_role_policy" "query_opensearch" {
  name = "${var.prefix}-query-opensearch"
  role = var.lambda_query_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["aoss:APIAccessAll"]
      Resource = aws_opensearchserverless_collection.vectors.arn
    }]
  })
}

resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${var.prefix}-data-access"
  type        = "data"
  description = "Data access for Lambda functions"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission   = [
            "aoss:CreateCollectionItems", 
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission   = [
            "aoss:CreateIndex",
            "aoss:WriteDocument",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument"
          ]
        }
      ]
      Principal = concat(
        [
          var.lambda_embedder_role_arn,
          var.lambda_query_role_arn,
        ],
        var.opensearch_admin_arns
      )
    }
  ])
}