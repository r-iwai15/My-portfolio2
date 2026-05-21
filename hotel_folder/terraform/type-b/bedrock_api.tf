# 10. Bedrock + API Gateway (復活しました！)
# =====================================================
resource "aws_iam_role" "bedrock_lambda_role" {
  name = "hotel-bedrock-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_lambda_basic" {
  role       = aws_iam_role.bedrock_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_s3_bucket" "chatbot_logs" {
  bucket = "hotel-innovative-chatbot-logs-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = "hotel-chatbot-logs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "chatbot_logs" {
  bucket = aws_s3_bucket.chatbot_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "chatbot_logs" {
  bucket                  = aws_s3_bucket.chatbot_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role_policy" "bedrock_invoke_policy" {
  name = "hotel-llm-chatbot-policy"
  role = aws_iam_role.bedrock_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Bedrock不要: VPC内LLMサーバーにHTTPで直接アクセスするため
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${aws_s3_bucket.chatbot_logs.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/hotel-bedrock-chatbot:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_lambda_function" "bedrock_chatbot" {
  function_name = "hotel-bedrock-chatbot"
  role          = aws_iam_role.bedrock_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 60 # vLLM初回レスポンスに余裕を持たせる

  filename         = fileexists(var.chatbot_lambda_zip_path) ? var.chatbot_lambda_zip_path : data.archive_file.dummy_chatbot.output_path
  source_code_hash = fileexists(var.chatbot_lambda_zip_path) ? filebase64sha256(var.chatbot_lambda_zip_path) : data.archive_file.dummy_chatbot.output_base64sha256

  vpc_config {
    subnet_ids         = module.vpc.lambda_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      # BedrockからVPC内ローカルLLMサーバーへ切り替え
      LLM_ENDPOINT       = "http://${aws_instance.llm_server.private_ip}:8000/v1"
      LLM_MODEL_ID       = "Qwen/Qwen2.5-7B-Instruct"
      CHATBOT_LOG_BUCKET = aws_s3_bucket.chatbot_logs.bucket
      SYSTEM_PROMPT      = "あなたはホテルの予約アシスタントです。"
    }
  }

  tags = {
    Name = "hotel-local-llm-chatbot"
  }
}

module "chatbot_log_group" {
  source            = "../modules/cloudwatch_log_group"
  name              = "/aws/lambda/${aws_lambda_function.bedrock_chatbot.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_apigatewayv2_api" "chatbot" {
  name          = "hotel-chatbot-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://${aws_cloudfront_distribution.hotel.domain_name}"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "chatbot" {
  api_id             = aws_apigatewayv2_api.chatbot.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.bedrock_chatbot.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.chatbot.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.hotel_app.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.hotel.id}"
  }
}

resource "aws_apigatewayv2_route" "chatbot" {
  api_id             = aws_apigatewayv2_api.chatbot.id
  route_key          = "POST /chat"
  target             = "integrations/${aws_apigatewayv2_integration.chatbot.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

module "apigw_access_log_group" {
  source            = "../modules/cloudwatch_log_group"
  name              = "/aws/apigateway/hotel-innovative-chatbot"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_apigatewayv2_stage" "chatbot" {
  api_id      = aws_apigatewayv2_api.chatbot.id
  name        = "prod"
  auto_deploy = true

  # [FIX] アクセスログを有効化
  access_log_settings {
    destination_arn = module.apigw_access_log_group.arn
    format          = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"requestTime\":\"$context.requestTime\", \"routeKey\":\"$context.routeKey\", \"status\":\"$context.status\", \"responseLength\":\"$context.responseLength\" }"
  }
}

resource "aws_lambda_permission" "apigw_chatbot" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bedrock_chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot.execution_arn}/*/*"
}

# =====================================================
