# 7. Lambda Functions
# =====================================================
resource "aws_lambda_function" "reader" {
  function_name    = "${var.app_name}-reader"
  role             = aws_iam_role.reader_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = fileexists(var.reader_zip_path) ? var.reader_zip_path : data.archive_file.dummy.output_path
  source_code_hash = fileexists(var.reader_zip_path) ? filebase64sha256(var.reader_zip_path) : data.archive_file.dummy.output_base64sha256
  timeout          = 30
  memory_size      = 512

  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.reservations.name
    }
  }
}

resource "aws_lambda_function" "interface" {
  function_name    = "${var.app_name}-interface"
  role             = aws_iam_role.interface_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = fileexists(var.interface_zip_path) ? var.interface_zip_path : data.archive_file.dummy.output_path
  source_code_hash = fileexists(var.interface_zip_path) ? filebase64sha256(var.interface_zip_path) : data.archive_file.dummy.output_base64sha256
  timeout          = 30
  memory_size      = 512

  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }

  environment {
    variables = {
      BEDROCK_AGENT_ID       = aws_bedrockagent_agent.orchestrator.agent_id
      BEDROCK_AGENT_ALIAS_ID = aws_bedrockagent_agent_alias.prod.agent_alias_id
    }
  }
}

resource "aws_lambda_function" "reservation" {
  function_name    = "${var.app_name}-reservation"
  role             = aws_iam_role.reservation_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = fileexists(var.reservation_zip_path) ? var.reservation_zip_path : data.archive_file.dummy.output_path
  source_code_hash = fileexists(var.reservation_zip_path) ? filebase64sha256(var.reservation_zip_path) : data.archive_file.dummy.output_base64sha256
  timeout          = 30
  memory_size      = 512

  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.reservations.name
    }
  }
}

resource "aws_lambda_permission" "apigw_interface" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.interface.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "bedrock_reader" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reader.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.orchestrator.agent_arn
}

resource "aws_lambda_permission" "bedrock_reservation" {
  statement_id  = "AllowBedrockInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reservation.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = aws_bedrockagent_agent.orchestrator.agent_arn
}

# =====================================================
