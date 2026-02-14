# Staging Environment Configuration

environment = "staging"
aws_region  = "us-east-1"

# Lambda Configuration
lambda_runtime = "python3.12"
lambda_memory  = 128
lambda_timeout = 10

# DynamoDB Configuration
dynamodb_billing_mode = "PAY_PER_REQUEST"

# CloudWatch Logs Configuration
log_retention_days = 14

# API Gateway Throttling
api_throttle_rate_limit  = 100
api_throttle_burst_limit = 50

# VPC Configuration (disabled for staging)
enable_vpc = false
vpc_id     = ""
subnet_ids = []

# Monitoring Configuration
alarm_email = "devops-staging@example.com"

# Resource Tags
tags = {
  Environment = "staging"
  Team        = "platform"
  CostCenter  = "engineering"
}
