output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.name
}

output "terraform_deploy_role_arn" {
  description = "ARN of the Terraform deployment role for CI/CD"
  value       = aws_iam_role.terraform_deploy.arn
}

output "terraform_deploy_role_name" {
  description = "Name of the Terraform deployment role"
  value       = aws_iam_role.terraform_deploy.name
}
