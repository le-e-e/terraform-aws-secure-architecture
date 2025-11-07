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