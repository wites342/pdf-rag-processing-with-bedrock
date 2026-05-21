resource "time_sleep" "wait_for_collection" {
  create_duration = "60s"

  depends_on = [
    aws_opensearchserverless_collection.vectors
  ]
}

resource "opensearch_index" "vectors" {
  name      = var.index_name
  index_knn = true

  mappings = jsonencode({
    properties = {
      text      = { type = "text" }
      source    = { type = "keyword" }
      chunk_id  = { type = "integer" }
      embedding = {
        type      = "knn_vector"
        dimension = 1024
      }
    }
  })

  force_destroy = true
  
  depends_on = [time_sleep.wait_for_collection]
}