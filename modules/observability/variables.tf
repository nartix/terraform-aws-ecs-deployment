variable "name" {
  description = "Name prefix for log groups."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "Optional KMS key ID or ARN for CloudWatch log encryption."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
