output "compliance_kms_arn" {
  value       = aws_kms_key.compliance.arn
  description = "KMS key for compliance logs and encryption."
}

output "compliance_logs_bucket" {
  value       = aws_s3_bucket.compliance_logs.id
  description = "S3 bucket for compliance log storage (VPC flow logs go to CloudWatch Logs, not this bucket)."
}

output "workload_vpc_id" {
  value       = aws_vpc.workload.id
  description = "Placeholder workload VPC (attach to TGW in full design)."
}
