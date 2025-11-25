variable "backup_vault_name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "tags" {
  type        = map(string)
  default     = {}
}

