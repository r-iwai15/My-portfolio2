output "vpc_id" {
  value       = aws_vpc.internal.id
  description = "Internal-only VPC id."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnets for internal workloads (e.g. EC2 Session Manager)."
}

output "internal_artifacts_bucket" {
  value       = aws_s3_bucket.internal_artifacts.id
  description = "KMS-encrypted bucket for internal artifacts."
}

output "kms_key_arn" {
  value       = aws_kms_key.main.arn
  description = "CMK ARN used by flow logs and S3 encryption."
}
