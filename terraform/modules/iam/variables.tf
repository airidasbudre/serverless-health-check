variable "environment" {
  description = "Environment name (e.g., staging, prod)"
  type        = string
}

variable "enable_vpc" {
  description = "Whether Lambda is deployed in VPC (requires VPC permissions)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
