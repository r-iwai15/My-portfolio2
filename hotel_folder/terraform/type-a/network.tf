module "vpc" {
  source                  = "../modules/vpc_type_a"
  region                  = var.region
  app_name                = var.app_name
  dynamodb_prefix_list_id = data.aws_prefix_list.dynamodb.id
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = module.vpc.vpc_id
  service_name    = "com.amazonaws.${var.region}.dynamodb"
  route_table_ids = [module.vpc.private_route_table_id]
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.lambda_security_group_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "cognito" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.cognito-idp"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.lambda_security_group_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "kms" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.lambda_security_group_id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.vpc.lambda_security_group_id]
  private_dns_enabled = true
}

module "flow_log_group" {
  source            = "../modules/cloudwatch_log_group"
  name              = "/aws/vpc/flow-log/${var.app_name}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_iam_role" "flow_log_role" {
  name = "${var.app_name}-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${module.flow_log_group.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = module.vpc.vpc_id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = module.flow_log_group.arn
}
