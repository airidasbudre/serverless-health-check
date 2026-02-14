output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "health_check_url" {
  description = "Full URL for health check endpoint"
  value       = module.api_gateway.stage_invoke_url
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = module.lambda.function_arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = module.dynamodb.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb.table_arn
}

output "kms_key_id" {
  description = "ID of the KMS key for DynamoDB encryption"
  value       = module.kms.key_id
}

output "kms_key_alias" {
  description = "Alias of the KMS key"
  value       = module.kms.key_alias
}

output "iam_lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_role_arn
}

output "iam_terraform_deploy_role_arn" {
  description = "ARN of the Terraform deployment role for CI/CD"
  value       = module.iam.terraform_deploy_role_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = module.monitoring.sns_topic_arn
}

output "log_group_name" {
  description = "Name of the Lambda CloudWatch log group"
  value       = module.lambda.log_group_name
}
