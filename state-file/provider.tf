provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project   = "state-file"
      ManagedBy = "terraform"
    }
  }
}