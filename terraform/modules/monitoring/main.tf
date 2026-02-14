data "aws_region" "current" {}

# SNS Topic for Alarm Notifications
resource "aws_sns_topic" "alarms" {
  name = "${var.environment}-health-check-alarms"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-health-check-alarms"
      Environment = var.environment
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Local variables for calculated thresholds
locals {
  # Lambda duration threshold: 80% of timeout (in milliseconds)
  lambda_duration_threshold = var.lambda_timeout * 1000 * (var.lambda_duration_threshold_percentage / 100)
}

# Lambda Alarms
# Error count alarm - fires on any errors (2 out of 3 datapoints to reduce noise)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Lambda function has errors (2 of 3 datapoints). Check CloudWatch Logs for error details: /aws/lambda/${var.lambda_function_name}"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-errors"
      Environment = var.environment
      Severity    = "critical"
    }
  )
}

# Error rate alarm - fires when error rate exceeds threshold percentage
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${var.environment}-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.lambda_error_rate_threshold
  alarm_description   = "Alert when Lambda error rate exceeds ${var.lambda_error_rate_threshold}%"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
    return_data = false
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
    return_data = false
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-error-rate"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.environment}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = local.lambda_duration_threshold
  alarm_description   = "Alert when Lambda p99 duration exceeds ${var.lambda_duration_threshold_percentage}% of timeout (${local.lambda_duration_threshold}ms). Timeout is ${var.lambda_timeout}s."
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-duration"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.environment}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when Lambda function is throttled. Check reserved concurrency and account limits."
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-throttles"
      Environment = var.environment
      Severity    = "critical"
    }
  )
}

# Lambda concurrent executions alarm
resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  alarm_name          = "${var.environment}-lambda-concurrent-executions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Maximum"
  threshold           = 900 # 90% of default account limit (1000)
  alarm_description   = "Alert when Lambda concurrent executions approach account limit (default: 1000)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-concurrent-executions"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

# Log Metric Filter for Lambda ERROR patterns
resource "aws_cloudwatch_log_metric_filter" "lambda_error_patterns" {
  name           = "${var.environment}-lambda-error-patterns"
  log_group_name = var.lambda_log_group_name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "LambdaErrorLogCount"
    namespace = "CustomMetrics/${var.environment}"
    value     = "1"
    default_value = 0
  }
}

# Alarm for error log patterns
resource "aws_cloudwatch_metric_alarm" "lambda_error_logs" {
  alarm_name          = "${var.environment}-lambda-error-logs"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 1
  metric_name         = "LambdaErrorLogCount"
  namespace           = "CustomMetrics/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when ERROR log patterns are detected in Lambda logs"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-lambda-error-logs"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

# API Gateway Alarms
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = var.api_5xx_threshold
  alarm_description   = "Alert when API Gateway returns more than ${var.api_5xx_threshold} 5xx errors (2 of 3 datapoints). Indicates backend/Lambda issues."
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-api-5xx-errors"
      Environment = var.environment
      Severity    = "critical"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.environment}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_4xx_threshold
  alarm_description   = "Alert when API Gateway 4xx errors exceed ${var.api_4xx_threshold} (indicates client errors/bad requests)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-api-4xx-errors"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.environment}-api-latency-p99"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.api_latency_p99_threshold_ms
  alarm_description   = "Alert when API Gateway p99 integration latency exceeds ${var.api_latency_p99_threshold_ms}ms"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-api-latency-p99"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

# DynamoDB Alarms
resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  alarm_name          = "${var.environment}-dynamodb-system-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 1
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when DynamoDB has system errors (AWS-side issues)"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-dynamodb-system-errors"
      Environment = var.environment
      Severity    = "critical"
    }
  )
}

# Monitor read throttles
resource "aws_cloudwatch_metric_alarm" "dynamodb_read_throttles" {
  alarm_name          = "${var.environment}-dynamodb-read-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when DynamoDB read requests are throttled. Consider increasing read capacity or using on-demand billing."
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-dynamodb-read-throttles"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

# Monitor write throttles
resource "aws_cloudwatch_metric_alarm" "dynamodb_write_throttles" {
  alarm_name          = "${var.environment}-dynamodb-write-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when DynamoDB write requests are throttled. Consider increasing write capacity or using on-demand billing."
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-dynamodb-write-throttles"
      Environment = var.environment
      Severity    = "warning"
    }
  )
}

# Composite Alarm - Overall Service Health
resource "aws_cloudwatch_composite_alarm" "service_health" {
  alarm_name          = "${var.environment}-service-health-composite"
  alarm_description   = "Composite alarm for overall service health. Triggers when multiple critical alarms fire."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  # Trigger when any 2 critical alarms are in ALARM state
  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.lambda_errors.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.lambda_throttles.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.api_5xx_errors.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.dynamodb_system_errors.alarm_name})"

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-service-health-composite"
      Environment = var.environment
      Severity    = "critical"
    }
  )
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-health-check-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Header text widget
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# ${upper(var.environment)} Health Check Service Dashboard\nLast updated: {{date}}"
        }
      },
      # Lambda Invocations and Errors
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Invocations", color = "#1f77b4", dimensions = { FunctionName = var.lambda_function_name } }],
            [".", "Errors", { stat = "Sum", label = "Errors", color = "#d62728", yAxis = "right", dimensions = { FunctionName = var.lambda_function_name } }],
            [".", "Throttles", { stat = "Sum", label = "Throttles", color = "#ff7f0e", yAxis = "right", dimensions = { FunctionName = var.lambda_function_name } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "Lambda Invocations & Errors"
          yAxis = {
            left = {
              label = "Invocations"
            }
            right = {
              label = "Errors/Throttles"
            }
          }
          annotations = {
            horizontal = [
              {
                value = 0
                label = "Error Threshold"
                color = "#d62728"
              }
            ]
          }
        }
      },
      # Lambda Duration
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Avg Duration", dimensions = { FunctionName = var.lambda_function_name } }],
            ["...", { stat = "p99", label = "p99 Duration", dimensions = { FunctionName = var.lambda_function_name } }],
            ["...", { stat = "Maximum", label = "Max Duration", dimensions = { FunctionName = var.lambda_function_name } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "Lambda Duration (ms)"
          yAxis = {
            left = {
              label = "Duration (ms)"
            }
          }
          annotations = {
            horizontal = [
              {
                value = local.lambda_duration_threshold
                label = "Duration Alarm (${var.lambda_duration_threshold_percentage}% of timeout)"
                color = "#ff7f0e"
              },
              {
                value = var.lambda_timeout * 1000
                label = "Timeout (${var.lambda_timeout}s)"
                color = "#d62728"
              }
            ]
          }
        }
      },
      # Lambda Concurrent Executions
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", { stat = "Maximum", label = "Concurrent Executions", dimensions = { FunctionName = var.lambda_function_name } }]
          ]
          period = 60
          region = data.aws_region.current.name
          title  = "Lambda Concurrent Executions"
          yAxis = {
            left = {
              label = "Count"
            }
          }
          annotations = {
            horizontal = [
              {
                value = 900
                label = "Alarm Threshold"
                color = "#ff7f0e"
              }
            ]
          }
        }
      },
      # API Gateway Requests
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "Total Requests", dimensions = { ApiId = var.api_id } }],
            [".", "4XXError", { stat = "Sum", label = "4xx Errors", yAxis = "right", dimensions = { ApiId = var.api_id } }],
            [".", "5XXError", { stat = "Sum", label = "5xx Errors", yAxis = "right", dimensions = { ApiId = var.api_id } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "API Gateway Requests & Errors"
          yAxis = {
            left = {
              label = "Total Requests"
            }
            right = {
              label = "Errors"
            }
          }
        }
      },
      # API Gateway Latency
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "IntegrationLatency", { stat = "Average", label = "Avg Latency", dimensions = { ApiId = var.api_id } }],
            ["...", { stat = "p99", label = "p99 Latency", dimensions = { ApiId = var.api_id } }],
            [".", "Latency", { stat = "p99", label = "p99 Total Latency", dimensions = { ApiId = var.api_id } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "API Gateway Latency (ms)"
          yAxis = {
            left = {
              label = "Latency (ms)"
            }
          }
          annotations = {
            horizontal = [
              {
                value = var.api_latency_p99_threshold_ms
                label = "Latency Alarm"
                color = "#ff7f0e"
              }
            ]
          }
        }
      },
      # DynamoDB Operations
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", { stat = "Sum", label = "Read Capacity", dimensions = { TableName = var.dynamodb_table_name } }],
            [".", "ConsumedWriteCapacityUnits", { stat = "Sum", label = "Write Capacity", dimensions = { TableName = var.dynamodb_table_name } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "DynamoDB Consumed Capacity"
          yAxis = {
            left = {
              label = "Capacity Units"
            }
          }
        }
      },
      # DynamoDB Errors and Throttles
      {
        type   = "metric"
        x      = 0
        y      = 19
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "SystemErrors", { stat = "Sum", label = "System Errors", dimensions = { TableName = var.dynamodb_table_name } }],
            [".", "UserErrors", { stat = "Sum", label = "User Errors", dimensions = { TableName = var.dynamodb_table_name } }],
            [".", "ReadThrottleEvents", { stat = "Sum", label = "Read Throttles", dimensions = { TableName = var.dynamodb_table_name } }],
            [".", "WriteThrottleEvents", { stat = "Sum", label = "Write Throttles", dimensions = { TableName = var.dynamodb_table_name } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "DynamoDB Errors & Throttles"
          yAxis = {
            left = {
              label = "Count"
            }
          }
        }
      },
      # Error Rate Metric Math
      {
        type   = "metric"
        x      = 12
        y      = 19
        width  = 12
        height = 6
        properties = {
          metrics = [
            [{ expression = "(errors / invocations) * 100", label = "Error Rate (%)", id = "error_rate", yAxis = "left" }],
            ["AWS/Lambda", "Errors", { id = "errors", visible = false, dimensions = { FunctionName = var.lambda_function_name } }],
            [".", "Invocations", { id = "invocations", visible = false, dimensions = { FunctionName = var.lambda_function_name } }]
          ]
          period = 300
          region = data.aws_region.current.name
          title  = "Lambda Error Rate (%)"
          yAxis = {
            left = {
              label = "Error Rate (%)"
              min   = 0
            }
          }
          annotations = {
            horizontal = [
              {
                value = var.lambda_error_rate_threshold
                label = "Error Rate Alarm (${var.lambda_error_rate_threshold}%)"
                color = "#d62728"
              }
            ]
          }
        }
      }
    ]
  })
}
