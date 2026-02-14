variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption at rest"
  type        = string
}

variable "tags" {
  description = "Tags to apply to DynamoDB resources"
  type        = map(string)
  default     = {}
}
