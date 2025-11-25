output "guardduty_detector_id" {
  description = "GuardDuty Detector ID"
  value       = var.enable ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_publishing_destination_id" {
  description = "GuardDuty Publishing Destination ID"
  value       = var.enable ? aws_guardduty_publishing_destination.main[0].id : null
}

output "s3_bucket_id" {
  description = "GuardDuty S3 Bucket ID"
  value       = aws_s3_bucket.guardduty_s3_bucket.id
}

output "s3_bucket_arn" {
  description = "GuardDuty S3 Bucket ARN"
  value       = aws_s3_bucket.guardduty_s3_bucket.arn
}

output "s3_bucket_name" {
  description = "GuardDuty S3 Bucket Name"
  value       = aws_s3_bucket.guardduty_s3_bucket.id
}

output "kms_key_id" {
  description = "GuardDuty KMS Key ID"
  value       = aws_kms_key.guardduty_s3_bucket_kms_key.id
}

output "kms_key_arn" {
  description = "GuardDuty KMS Key ARN"
  value       = aws_kms_key.guardduty_s3_bucket_kms_key.arn
}