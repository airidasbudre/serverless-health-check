output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/deeplink.js?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alarm_arns" {
  description = "ARNs of all CloudWatch alarms"
  value = {
    lambda_errors                 = aws_cloudwatch_metric_alarm.lambda_errors.arn
    lambda_error_rate             = aws_cloudwatch_metric_alarm.lambda_error_rate.arn
    lambda_duration               = aws_cloudwatch_metric_alarm.lambda_duration.arn
    lambda_throttles              = aws_cloudwatch_metric_alarm.lambda_throttles.arn
    lambda_concurrent_executions  = aws_cloudwatch_metric_alarm.lambda_concurrent_executions.arn
    lambda_error_logs             = aws_cloudwatch_metric_alarm.lambda_error_logs.arn
    api_5xx_errors                = aws_cloudwatch_metric_alarm.api_5xx_errors.arn
    api_4xx_errors                = aws_cloudwatch_metric_alarm.api_4xx_errors.arn
    api_latency                   = aws_cloudwatch_metric_alarm.api_latency.arn
    dynamodb_system_errors        = aws_cloudwatch_metric_alarm.dynamodb_system_errors.arn
    dynamodb_read_throttles       = aws_cloudwatch_metric_alarm.dynamodb_read_throttles.arn
    dynamodb_write_throttles      = aws_cloudwatch_metric_alarm.dynamodb_write_throttles.arn
    service_health_composite      = aws_cloudwatch_composite_alarm.service_health.arn
  }
}

output "log_metric_filter_name" {
  description = "Name of the Lambda error log metric filter"
  value       = aws_cloudwatch_log_metric_filter.lambda_error_patterns.name
}
