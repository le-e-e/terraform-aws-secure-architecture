output "log_group_id" {
  description = "CloudWatch Log Group ID"
  value       = aws_cloudwatch_log_group.main.id
}

output "log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.main.arn
}

output "s3_bucket_id" {
  description = "S3 Bucket ID"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.main.arn
}