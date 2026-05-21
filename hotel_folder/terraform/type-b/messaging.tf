# =====================================================
resource "aws_sqs_queue" "reservation_queue" {
  name                              = "hotel-reservation-queue"
  visibility_timeout_seconds        = 300
  message_retention_seconds         = 86400
  kms_master_key_id                 = aws_kms_alias.main.name
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reservation_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "hotel-reservation-queue"
  }
}

# [FIX] SQSキューポリシー：EC2アプリロールからの送信のみ許可
resource "aws_sqs_queue_policy" "reservation_queue" {
  queue_url = aws_sqs_queue.reservation_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.app_role.arn }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.reservation_queue.arn
    }]
  })
}

resource "aws_sqs_queue" "reservation_dlq" {
  name                              = "hotel-reservation-dlq"
  message_retention_seconds         = 604800
  kms_master_key_id                 = aws_kms_alias.main.name
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name = "hotel-reservation-dlq"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "hotel-lambda-role"
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

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_sqs_ses" {
  name = "hotel-lambda-sqs-ses-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.reservation_queue.arn
      },
      {
        # [FIX] SES送信元を検証済みIDのARNに限定
        Effect = "Allow"
        Action = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = [
          "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/${var.from_email}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_lambda_function" "send_confirmation" {
  function_name = "hotel-send-reservation-confirmation"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  filename         = fileexists(var.lambda_zip_path) ? var.lambda_zip_path : data.archive_file.dummy_send_email.output_path
  source_code_hash = fileexists(var.lambda_zip_path) ? filebase64sha256(var.lambda_zip_path) : data.archive_file.dummy_send_email.output_base64sha256

  vpc_config {
    subnet_ids         = module.vpc.lambda_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
      FROM_EMAIL = var.from_email
    }
  }

  tags = {
    Name = "hotel-send-confirmation"
  }
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.reservation_queue.arn
  function_name    = aws_lambda_function.send_confirmation.arn
  batch_size       = 10
}

# =====================================================
