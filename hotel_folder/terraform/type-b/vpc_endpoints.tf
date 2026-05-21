# 13. VPC Endpoints (真の完全閉域網)
# =====================================================
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = module.vpc.vpc_id
  service_name    = "com.amazonaws.${var.region}.s3"
  route_table_ids = [module.vpc.private_route_table_id]
  tags = {
    Name = "hotel-innovative-s3-ep"
  }
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.lambda_subnet_ids
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true
  tags = {
    Name = "hotel-innovative-bedrock-ep"
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.lambda_subnet_ids
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true
  tags = {
    Name = "hotel-innovative-secrets-ep"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.lambda_subnet_ids
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true
  tags = {
    Name = "hotel-innovative-sqs-ep"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.lambda_subnet_ids
  security_group_ids  = [aws_security_group.lambda.id]
  private_dns_enabled = true
  tags = {
    Name = "hotel-innovative-logs-ep"
  }
}