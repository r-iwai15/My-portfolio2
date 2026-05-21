resource "aws_dynamodb_table" "blocked_ips" {
  name         = "${var.name_prefix}-innovative-blocked-ips"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ip"

  attribute {
    name = "ip"
    type = "S"
  }

  ttl {
    attribute_name = "expire_at"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.name_prefix}-innovative-blocked-ips"
  }
}

resource "aws_iam_role" "sentinel_executioner" {
  name = "${var.name_prefix}-sentinel-executioner-role"
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

resource "aws_iam_role_policy" "sentinel_permissions" {
  name = "${var.name_prefix}-sentinel-policy"
  role = aws_iam_role.sentinel_executioner.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["wafv2:GetIPSet", "wafv2:UpdateIPSet"]
        Resource = var.waf_ipset_arn
      },
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:AdminDisableUser", "cognito-idp:AdminEnableUser"]
        Resource = var.cognito_user_pool_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.blocked_ips.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}-sentinel-executioner:*",
          "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${var.name_prefix}-sentinel-ip-release:*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "sentinel_executioner" {
  function_name = "${var.name_prefix}-sentinel-executioner"
  role          = aws_iam_role.sentinel_executioner.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.11"

  filename         = fileexists(var.sentinel_lambda_zip_path) ? var.sentinel_lambda_zip_path : var.dummy_sentinel_zip_path
  source_code_hash = fileexists(var.sentinel_lambda_zip_path) ? filebase64sha256(var.sentinel_lambda_zip_path) : var.dummy_sentinel_source_hash

  environment {
    variables = {
      WAF_IPSET_ID   = var.waf_ipset_id
      WAF_IPSET_NAME = var.waf_ipset_name
      SCOPE          = "CLOUDFRONT"
      REGION         = "us-east-1"
      USER_POOL_ID   = var.cognito_user_pool_id
      TRACKING_TABLE = aws_dynamodb_table.blocked_ips.name
      TTL_HOURS      = "24"
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_sentinel" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sentinel_executioner.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${var.chatbot_log_group_arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "sentinel_trigger" {
  name            = "sentinel-chatbot-injection-trigger"
  log_group_name  = var.chatbot_log_group_name
  filter_pattern  = "?\"IGNORE ALL PREVIOUS INSTRUCTIONS\" ?\"SYSTEM PROMPT\""
  destination_arn = aws_lambda_function.sentinel_executioner.arn
  depends_on      = [aws_lambda_permission.allow_cloudwatch_sentinel]
}

resource "aws_lambda_function" "sentinel_release" {
  function_name = "${var.name_prefix}-sentinel-ip-release"
  role          = aws_iam_role.sentinel_executioner.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.11"

  filename         = fileexists(var.sentinel_release_zip_path) ? var.sentinel_release_zip_path : var.dummy_sentinel_zip_path
  source_code_hash = fileexists(var.sentinel_release_zip_path) ? filebase64sha256(var.sentinel_release_zip_path) : var.dummy_sentinel_source_hash

  environment {
    variables = {
      WAF_IPSET_ID   = var.waf_ipset_id
      WAF_IPSET_NAME = var.waf_ipset_name
      SCOPE          = "CLOUDFRONT"
      REGION         = "us-east-1"
      USER_POOL_ID   = var.cognito_user_pool_id
      TTL_HOURS      = "24"
      TRACKING_TABLE = aws_dynamodb_table.blocked_ips.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "sentinel_release_schedule" {
  name                = "${var.name_prefix}-sentinel-release-schedule"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "sentinel_release_target" {
  rule      = aws_cloudwatch_event_rule.sentinel_release_schedule.name
  target_id = "SentinelRelease"
  arn       = aws_lambda_function.sentinel_release.arn
}

resource "aws_lambda_permission" "allow_eventbridge_release" {
  statement_id  = "AllowEventBridgeRelease"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sentinel_release.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sentinel_release_schedule.arn
}
