resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/25"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.prefix}-ai-rag-on-bedrock-vpc"
  }
}

resource "aws_subnet" "private" {
  for_each = toset(var.vpc_availability_zones)
 
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 1, index(var.vpc_availability_zones, each.value))
  availability_zone = "${each.value}"

  tags = {
    Name = "${var.prefix}-private-${each.value}"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.prefix}-ai-rag-on-bedrock-vpc-endpoints"
  description = "Allow HTTPS from Lambda"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-vpc-endpoints"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_from_lambda" {
  security_group_id            = aws_security_group.vpc_endpoints.id
  description                  = "HTTPS from Lambda"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.lambda.id
}

resource "aws_security_group" "lambda" {
  name        = "${var.prefix}-vpce-access-for-lambda"
  description = "Allow outbound HTTPS to VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-lambda"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_vpc_endpoints" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "HTTPS to VPC endpoints"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.vpc_endpoints.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_s3" {
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS to S3 via Gateway endpoint"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_prefix_list.s3.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-ai-rag-on-bedrock-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}