# Production Environment Configuration

environment = "prod"
aws_region  = "us-east-1"

# Lambda Configuration
lambda_runtime = "python3.12"
lambda_memory  = 256
lambda_timeout = 30

# DynamoDB Configuration
dynamodb_billing_mode = "PAY_PER_REQUEST"

# CloudWatch Logs Configuration
log_retention_days = 90

# API Gateway Throttling
api_throttle_rate_limit  = 1000
api_throttle_burst_limit = 500

# VPC Configuration (disabled for production, enable if needed)
enable_vpc = false
vpc_id     = ""
subnet_ids = []

# Monitoring Configuration
alarm_email = "devops-prod@example.com"

# Resource Tags
tags = {
  Environment = "prod"
  Team        = "platform"
  CostCenter  = "engineering"
}
