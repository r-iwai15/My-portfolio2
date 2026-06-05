# コンプライアンスログ・暗号化のたたき（CIS / NIST 運用の前提となる保管先）

resource "aws_kms_key" "compliance" {
  description             = "${var.name_prefix} compliance CMK"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootFullControl"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLogsAndTrail"
        Effect = "Allow"
        Principal = {
          Service = [
            "logs.${var.region}.amazonaws.com",
            "cloudtrail.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "compliance" {
  name          = "alias/${var.name_prefix}-compliance"
  target_key_id = aws_kms_key.compliance.key_id
}

resource "aws_s3_bucket" "compliance_logs" {
  bucket = "${var.name_prefix}-compliance-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "compliance_logs" {
  bucket                  = aws_s3_bucket.compliance_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.compliance.arn
    }
    bucket_key_enabled = true
  }
}

# コンプライアンスログは改ざん・誤削除に備えてバージョニングを有効化
resource "aws_s3_bucket_versioning" "compliance_logs" {
  bucket = aws_s3_bucket.compliance_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 転送時暗号化（TLS）を強制：HTTP 経由のアクセスは拒否
resource "aws_s3_bucket_policy" "compliance_logs" {
  bucket     = aws_s3_bucket.compliance_logs.id
  depends_on = [aws_s3_bucket_public_access_block.compliance_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.compliance_logs.arn,
          "${aws_s3_bucket.compliance_logs.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "security_findings" {
  name              = "/aws/${var.name_prefix}/security-findings"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.compliance.arn
}
