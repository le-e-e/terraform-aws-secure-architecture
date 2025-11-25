variable "project_name" {
  type        = string
}

variable "enable" {
  type        = bool
  default     = true 
}

variable "finding_publishing_frequency" {
  type        = string
  default     = "FIFTEEN_MINUTES"
}

variable "tags" {
  type        = map(string)
}

variable "guardduty_s3_bucket_name" {
  type        = string
  default     = "guardduty-s3-bucket-withlee"
}


variable "guardduty_kms_key_account_id" {
  type        = string
}

variable "public_access_block" {
  type        = bool
  default     = true
}

variable "guardduty_s3_bucket_kms_key_deletion_window_in_days" {
  type        = number
  default     = 7
}

variable "guardduty_s3_bucket_kms_key_enable_key_rotation" {
  type        = bool
  default     = true
}

