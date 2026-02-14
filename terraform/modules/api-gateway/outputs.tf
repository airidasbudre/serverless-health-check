output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.health_api.id
}

output "api_endpoint" {
  description = "Endpoint URL of the API Gateway"
  value       = aws_apigatewayv2_api.health_api.api_endpoint
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_apigatewayv2_api.health_api.execution_arn
}

output "stage_invoke_url" {
  description = "Full invoke URL for the default stage"
  value       = "${aws_apigatewayv2_api.health_api.api_endpoint}/health"
}
