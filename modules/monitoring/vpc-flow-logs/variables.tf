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

variable "s3_bucket_lifecycle_configuration" {
  type        = map(string)
  default     = {}
}

variable "s3_bucket_public_access_block" {
  type        = bool
  default     = true
}

