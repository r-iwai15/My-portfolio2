resource "aws_s3_bucket" "internal_artifacts" {
  bucket = "${var.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "internal_artifacts" {
  bucket = aws_s3_bucket.internal_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "internal_artifacts" {
  bucket = aws_s3_bucket.internal_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "internal_artifacts" {
  bucket = aws_s3_bucket.internal_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "internal_artifacts" {
  bucket = aws_s3_bucket.internal_artifacts.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# 転送時暗号化（TLS）を強制：HTTP 経由のアクセスは拒否
resource "aws_s3_bucket_policy" "internal_artifacts" {
  bucket     = aws_s3_bucket.internal_artifacts.id
  depends_on = [aws_s3_bucket_public_access_block.internal_artifacts]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.internal_artifacts.arn,
          "${aws_s3_bucket.internal_artifacts.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}
