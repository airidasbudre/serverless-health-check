variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime (e.g., python3.12)"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "health_check.lambda_handler"
}

variable "memory_size" {
  description = "Amount of memory in MB for Lambda function"
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Timeout in seconds for Lambda function"
  type        = number
  default     = 10
}

variable "source_code_path" {
  description = "Path to Lambda function source code"
  type        = string
}

variable "iam_role_arn" {
  description = "ARN of IAM role for Lambda execution"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of DynamoDB table for environment variable"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_vpc" {
  description = "Whether to deploy Lambda in VPC"
  type        = bool
  default     = false
}

variable "vpc_subnet_ids" {
  description = "List of VPC subnet IDs for Lambda (required if enable_vpc is true)"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "List of VPC security group IDs for Lambda (required if enable_vpc is true)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to Lambda resources"
  type        = map(string)
  default     = {}
}
