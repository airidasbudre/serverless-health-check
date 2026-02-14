variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds (used to calculate duration threshold)"
  type        = number
  default     = 30
}

variable "lambda_log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  type        = string
}

variable "api_id" {
  description = "ID of the API Gateway to monitor"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to monitor"
  type        = string
}

variable "alarm_email" {
  description = "Email address for alarm notifications"
  type        = string
}

variable "tags" {
  description = "Tags to apply to monitoring resources"
  type        = map(string)
  default     = {}
}

# Environment-specific thresholds
variable "lambda_error_rate_threshold" {
  description = "Lambda error rate threshold percentage (0-100)"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold_percentage" {
  description = "Lambda duration threshold as percentage of timeout (0-100)"
  type        = number
  default     = 80
}

variable "api_5xx_threshold" {
  description = "API Gateway 5xx error count threshold"
  type        = number
  default     = 5
}

variable "api_4xx_threshold" {
  description = "API Gateway 4xx error count threshold"
  type        = number
  default     = 20
}

variable "api_latency_p99_threshold_ms" {
  description = "API Gateway p99 latency threshold in milliseconds"
  type        = number
  default     = 2000
}
