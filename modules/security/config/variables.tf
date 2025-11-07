variable "config_configuration_recorder_name" {
  type        = string
  default     = "config-configuration-recorder"
}

variable "config_delivery_channel_name" {
  type        = string
  default     = "config-delivery-channel"
}

variable "config_delivery_channel_s3_bucket_name" {
  type        = string
  default     = "config-s3-bucket-withlee"
}

variable "config_delivery_channel_s3_key_prefix" {
  type        = string
  default     = ""
}

variable "config_delivery_channel_sns_topic_arn" {
  type        = string
  default     = ""
}

variable "enable" {
  type        = bool
  default     = true
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "config_role_name" {
  type        = string
  default     = "config-role"
}

variable "config_role_policy_arn" {
  type        = string
  default     = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

variable "public_access_block" {
  type        = bool
  default     = true
}

variable "config_delivery_channel_s3_bucket_kms_key_deletion_window_in_days" {
  type        = number
  default     = 30
}

variable "config_delivery_channel_s3_bucket_kms_key_enable_key_rotation" {
  type        = bool
  default     = true
}

variable "config_delivery_channel_s3_bucket_kms_key_account_id" {
  type        = string
}