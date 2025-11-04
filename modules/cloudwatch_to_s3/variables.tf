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
  default     = "cloudwatch-to-s3-bucket"
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

variable "tags" {
  type        = map(string)
}

