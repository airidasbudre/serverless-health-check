variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of Lambda execution role that needs access to KMS key"
  type        = string
}

variable "tags" {
  description = "Tags to apply to KMS resources"
  type        = map(string)
  default     = {}
}
