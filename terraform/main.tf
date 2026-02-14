provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Environment = var.environment
        ManagedBy   = "terraform"
        Project     = "health-check"
      },
      var.tags
    )
  }
}

locals {
  lambda_source_path = "${path.module}/../lambda"
  function_name      = "${var.environment}-health-check-function"
  api_name           = "${var.environment}-health-api"

  # Security group IDs for VPC (if enabled)
  vpc_security_group_ids = var.enable_vpc && var.vpc_id != "" ? [
    aws_security_group.lambda[0].id
  ] : []
}

# VPC Security Group for Lambda (only if VPC enabled)
resource "aws_security_group" "lambda" {
  count = var.enable_vpc ? 1 : 0

  name        = "${var.environment}-lambda-sg"
  description = "Security group for Lambda function in VPC"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.environment}-lambda-sg"
  }
}

# IAM Module - Create roles first (no dependencies, uses constructed ARNs)
module "iam" {
  source = "./modules/iam"

  environment = var.environment
  enable_vpc  = var.enable_vpc

  tags = var.tags
}

# KMS Module - Requires IAM role for key policy
module "kms" {
  source = "./modules/kms"

  environment     = var.environment
  lambda_role_arn = module.iam.lambda_role_arn

  tags = var.tags
}

# DynamoDB Module - Requires KMS key
module "dynamodb" {
  source = "./modules/dynamodb"

  environment  = var.environment
  billing_mode = var.dynamodb_billing_mode
  kms_key_arn  = module.kms.key_arn

  tags = var.tags
}

# Lambda Module - Requires IAM role and DynamoDB table
module "lambda" {
  source = "./modules/lambda"

  environment          = var.environment
  function_name        = local.function_name
  runtime              = var.lambda_runtime
  memory_size          = var.lambda_memory
  timeout              = var.lambda_timeout
  source_code_path     = local.lambda_source_path
  iam_role_arn         = module.iam.lambda_role_arn
  dynamodb_table_name  = module.dynamodb.table_name
  log_retention_days   = var.log_retention_days
  enable_vpc           = var.enable_vpc
  vpc_subnet_ids       = var.subnet_ids
  vpc_security_group_ids = local.vpc_security_group_ids

  tags = var.tags
}

# API Gateway Module - Requires Lambda
module "api_gateway" {
  source = "./modules/api-gateway"

  environment           = var.environment
  api_name              = local.api_name
  lambda_invoke_arn     = module.lambda.invoke_arn
  lambda_function_name  = module.lambda.function_name
  throttle_rate_limit   = var.api_throttle_rate_limit
  throttle_burst_limit  = var.api_throttle_burst_limit

  tags = var.tags
}

# Monitoring Module - Requires all other resources
module "monitoring" {
  source = "./modules/monitoring"

  environment            = var.environment
  lambda_function_name   = module.lambda.function_name
  lambda_timeout         = var.lambda_timeout
  lambda_log_group_name  = module.lambda.log_group_name
  api_id                 = module.api_gateway.api_id
  dynamodb_table_name    = module.dynamodb.table_name
  alarm_email            = var.alarm_email

  # Environment-specific thresholds (can be overridden via variables)
  lambda_error_rate_threshold            = var.environment == "prod" ? 5 : 10
  lambda_duration_threshold_percentage   = var.environment == "prod" ? 80 : 90
  api_5xx_threshold                      = var.environment == "prod" ? 5 : 10
  api_4xx_threshold                      = var.environment == "prod" ? 20 : 50
  api_latency_p99_threshold_ms           = var.environment == "prod" ? 2000 : 3000

  tags = var.tags
}
