# ワークロード用プレースホルダ VPC（本番では TGW にスポーク接続）
resource "aws_vpc" "workload" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-workload-vpc"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.workload.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.region}a"

  tags = {
    Name = "${var.name_prefix}-private-a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.workload.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.region}c"

  tags = {
    Name = "${var.name_prefix}-private-c"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "/aws/vpc/flow-log/${var.name_prefix}-workload"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.compliance.arn
}

resource "aws_iam_role" "vpc_flow" {
  name = "${var.name_prefix}-vpc-flow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow" {
  name = "vpc-flow-logs"
  role = aws_iam_role.vpc_flow.id

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
      Resource = "${aws_cloudwatch_log_group.vpc_flow.arn}:*"
    }]
  })
}

resource "aws_flow_log" "workload" {
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.workload.id
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow.arn
  iam_role_arn         = aws_iam_role.vpc_flow.arn
}
