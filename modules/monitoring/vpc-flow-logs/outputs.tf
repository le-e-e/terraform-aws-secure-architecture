output "flow_log_id" {
  description = "VPC Flow Log ID"
  value       = aws_flow_log.main.id
}

output "s3_bucket_name" {
  description = "S3 bucket name for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs_bucket.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for VPC Flow Logs"
  value       = aws_s3_bucket.vpc_flow_logs_bucket.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.main.arn
}

