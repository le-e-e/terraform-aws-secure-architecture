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


output "delivery_stream_name" {
  description = "Delivery Stream Name"
  value       = aws_kinesis_firehose_delivery_stream.main.name
}

output "delivery_stream_arn" {
  description = "Delivery Stream ARN"
  value       = aws_kinesis_firehose_delivery_stream.main.arn
}

output "iam_role_name" {
  description = "IAM Role Name"
  value       = aws_iam_role.kinesis_firehose_role.name
}

output "iam_role_arn" {
  description = "IAM Role ARN"
  value       = aws_iam_role.kinesis_firehose_role.arn
}

output "iam_role_policy_name" {
  description = "IAM Role Policy Name"
  value       = aws_iam_role_policy.kinesis_firehose_role_policy.name
}


output "s3_bucket_name" {
  description = "S3 Bucket Name"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "S3 Bucket ARN"
  value       = aws_s3_bucket.main.arn
}

output "kms_key_id" {
  description = "KMS Key ID"
  value       = aws_kms_key.main.id
}

output "kms_key_arn" {
  description = "KMS Key ARN"
  value       = aws_kms_key.main.arn
}

output "kms_key_policy" {
  description = "KMS Key Policy"
  value       = aws_kms_key.main.policy
}

output "deletion_window_in_days" {
  description = "Deletion Window in Days"
  value       = aws_kms_key.main.deletion_window_in_days
}

output "enable_key_rotation" {
  description = "Enable Key Rotation"
  value       = aws_kms_key.main.enable_key_rotation
}
