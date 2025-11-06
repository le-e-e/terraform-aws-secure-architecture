variable "project_name" {
      type        = string
}

variable "log_group_name" {
  type        = string
}


variable "retention_in_days" {
    # 로그 보존 기간 일단위 (0은 무제한)
  type        = number
  default     = 7
}

variable "tags" {
  type        = map(string)
}

variable "bucket_name" {
  type        = string
  default     = "cloudwatch-to-s3-bucket-use-firehose-withlee"
}

variable "s3_bucket_notification_events" {
  type        = list(string)
  default     = ["s3:ObjectCreated:*"]
}

variable "s3_bucket_notification_filter_prefix" {
  type        = string
  default     = ""
}

variable "s3_bucket_notification_filter_suffix" {
  type        = string
  default     = ""
}

variable "delivery_stream_name" {
  type        = string
  default     = "cloudwatch-to-s3-delivery-stream"
}

variable "iam_role_name" {
  type        = string
  default     = "cloudwatch-to-s3-iam-role"
}

variable "iam_role_policy_name" {
  type        = string
  default     = "cloudwatch-to-s3-iam-role-policy"
}

variable "public_access_block" {
  type        = bool
  default     = true  
}

variable "kms_key_id" {
  type        = string
  default     = ""
}

variable "log_subscription_filter_name" {
  type        = string
  default     = "cloudwatch-to-s3-log-subscription-filter"
}

variable "filter_pattern" {
  type        = string
  default     = ""
}

variable "cloudwatch_to_s3_role_arn" {
  type        = string
  default     = ""
}

variable "cloudwatch_to_s3_role_name" {
  type        = string
  default     = "cloudwatch-to-s3-role"
}

variable "cloudwatch_to_s3_role_policy_name" {
  type        = string
  default     = "cloudwatch-to-s3-role-policy"
}

variable "cloudwatch_to_s3_role_policy_arn" {
  type        = string
  default     = ""
}

variable "kinesis_firehose_role_name" {
  type        = string
  default     = "kinesis-firehose-role"
}

variable "kinesis_firehose_role_policy_name" {
  type        = string
  default     = "kinesis-firehose-role-policy"
}