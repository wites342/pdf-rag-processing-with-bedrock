data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.region}.s3"
}