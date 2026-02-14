data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# HTTP API (API Gateway v2)
resource "aws_apigatewayv2_api" "health_api" {
  name          = var.api_name
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = merge(
    var.tags,
    {
      Name        = var.api_name
      Environment = var.environment
    }
  )
}

# Lambda Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.health_api.id
  integration_type = "AWS_PROXY"

  connection_type      = "INTERNET"
  integration_method   = "POST"
  integration_uri      = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

# GET /health route
resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.health_api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# POST /health route
resource "aws_apigatewayv2_route" "post_health" {
  api_id    = aws_apigatewayv2_api.health_api.id
  route_key = "POST /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Stage with auto-deploy and throttling
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.health_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.api_name}-default-stage"
      Environment = var.environment
    }
  )
}

# Lambda Permission for API Gateway to invoke the function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Scoped to this specific API Gateway
  source_arn = "${aws_apigatewayv2_api.health_api.execution_arn}/*/*"
}
