variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function to integrate"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function (for permissions)"
  type        = string
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags to apply to API Gateway resources"
  type        = map(string)
  default     = {}
}
