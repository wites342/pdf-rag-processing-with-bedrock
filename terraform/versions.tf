terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
    opensearch = {
      source  = "opensearch-project/opensearch"
      version = ">= 2.0"
    }
  }

  backend "s3" {
    bucket         = "future-solutions-terraform-state"
    key            = "ai-rag-on-bedrock/terraform.tfstate"
    region         = "eu-west-2"
    use_lockfile   = true
    encrypt        = true
  }
}