provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project   = "rag-on-bedrock-aft"
      ManagedBy = "terraform"
    }
  }
}