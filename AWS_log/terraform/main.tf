# --------------------------------------------------------------------------------------------------
# 1. 変数・共通設定
# --------------------------------------------------------------------------------------------------
locals {
  project_name = "security-log-analysis"
  region       = "ap-northeast-1"
}

data "aws_caller_identity" "current" {}

# --------------------------------------------------------------------------------------------------
# 2. ログ保存用S3バケット（コスト削減のため1日でログを消去するライフサイクル設定）
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${local.project_name}-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # ポートフォリオ用なので、バケット削除時に中身も消せるように設定
}

# 🔴修正③: パブリックアクセスブロックを追加
resource "aws_s3_bucket_public_access_block" "log_bucket" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "auto-delete-1-day"
    status = "Enabled"
    expiration {
      days = 1 # コスト抑制のため、1日でログを自動削除
    }
  }
}

# --------------------------------------------------------------------------------------------------
# 3. CloudTrail の設定 (API操作の監視)
# --------------------------------------------------------------------------------------------------
resource "aws_cloudtrail" "main" {
  name                          = "${local.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false # コストを抑えるため東京リージョンのみに限定
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.allow_log_writing]
}

# --------------------------------------------------------------------------------------------------
# 4. VPC Flow Logs の設定 (ネットワーク通信の監視)
# --------------------------------------------------------------------------------------------------
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${local.project_name}-vpc" }
}

resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_s3_bucket.log_bucket.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.test_vpc.id
}

# --------------------------------------------------------------------------------------------------
# 5. Athena の設定 (サーバーレス分析基盤)
# --------------------------------------------------------------------------------------------------
resource "aws_athena_database" "security_logs" {
  name   = "security_logs_db"
  bucket = aws_s3_bucket.log_bucket.id
}

# 🔴修正②: "primary"はデフォルトで存在するため名前を変更
resource "aws_athena_workgroup" "main" {
  name = "${local.project_name}-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.log_bucket.bucket}/athena-results/"
    }
  }
}

# --------------------------------------------------------------------------------------------------
# 6. S3バケットポリシー (CloudTrailとVPC Flow Logsからの書き込み許可)
# --------------------------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "allow_log_writing" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- CloudTrail ---
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.log_bucket.arn
        # 🔴修正④: confused deputy攻撃対策としてSourceArnを条件に追加
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${local.region}:${data.aws_caller_identity.current.account_id}:trail/${local.project_name}-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            # 🔴修正④: SourceArnを追加
            "aws:SourceArn" = "arn:aws:cloudtrail:${local.region}:${data.aws_caller_identity.current.account_id}:trail/${local.project_name}-trail"
          }
        }
      },
      # --- VPC Flow Logs ---
      # 🔴修正①: GetBucketAclが抜けていたので追加
      {
        Sid    = "AWSVPCFlowLogsAclCheck"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.log_bucket.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSVPCFlowLogsWrite"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}
