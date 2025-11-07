variable "cloudtrail_name" {
  type        = string
  default     = "cloudtrail"
}

variable "cloudtrail_bucket_name" {
  type        = string
  default     = "cloudtrail-bucket-withlee"
}

variable "cloudtrail_s3_key_prefix" {
  type        = string
  default     = ""
}

variable "cloudtrail_bucket_kms_key_arn" {
  type        = string
}

variable "public_access_block" {
  type        = bool
  default     = true
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "cloudtrail_bucket_kms_key_account_id" {
  type        = string
}
