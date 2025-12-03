variable "vpc_id" {
  type        = string
}

variable "project_name" {
  type        = string
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "traffic_type" {
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.traffic_type)
    error_message = "traffic_type must be ALL, ACCEPT, or REJECT"
  }
}

variable "enable_versioning" {
  type        = bool
  default     = false
}

variable "encryption_type" {
  type        = string
  default     = "aes256"
  validation {
    condition     = contains(["kms", "aes256"], var.encryption_type)
    error_message = "encryption_type must be 'kms' or 'aes256'"
  }
}

variable "lifecycle_glacier_days" {
  type        = number
  default     = 30
}

variable "lifecycle_deep_archive_days" {
  type        = number
  default     = 90
}

variable "lifecycle_expiration_days" {
  type        = number
  default     = 365
}

variable "enable_public_access_block" {
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  type        = number
  default     = 30
}

variable "kms_key_rotation" {
  type        = bool
  default     = true
}

variable "vpc_flow_logs_bucket_name" {
  description = "S3 bucket name for VPC Flow Logs. If empty, will be auto-generated with account_id and region for uniqueness"
  type        = string
  default     = ""
}
