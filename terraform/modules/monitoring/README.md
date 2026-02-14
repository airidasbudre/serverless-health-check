# CloudWatch Monitoring Module

This Terraform module provides comprehensive CloudWatch monitoring for the serverless health-check service, including alarms, dashboards, and SNS notifications.

## Features

### Alarms (13 Total)

#### Lambda Monitoring (6 alarms)
- **lambda-errors**: Fires when Lambda function has errors (2 of 3 datapoints)
- **lambda-error-rate**: Fires when error rate exceeds threshold percentage (5% prod, 10% staging)
- **lambda-duration**: Fires when p99 duration exceeds 80% of timeout (prod) or 90% (staging)
- **lambda-throttles**: Fires on any Lambda throttling events
- **lambda-concurrent-executions**: Fires when concurrent executions > 900 (approaching 1000 limit)
- **lambda-error-logs**: Fires when ERROR patterns detected in logs (via log metric filter)

#### API Gateway Monitoring (3 alarms)
- **api-5xx-errors**: Fires when 5xx errors exceed threshold (5 in prod, 10 in staging)
- **api-4xx-errors**: Fires when 4xx errors exceed threshold (20 in prod, 50 in staging)
- **api-latency-p99**: Fires when p99 integration latency exceeds 2s (prod) or 3s (staging)

#### DynamoDB Monitoring (3 alarms)
- **dynamodb-system-errors**: Fires on any DynamoDB system errors (AWS-side issues)
- **dynamodb-read-throttles**: Fires when read requests are throttled (> 5 in 5 minutes)
- **dynamodb-write-throttles**: Fires when write requests are throttled (> 5 in 5 minutes)

#### Composite Alarm (1 alarm)
- **service-health-composite**: Fires when any critical alarm is in ALARM state (overall health indicator)

### CloudWatch Dashboard

Comprehensive dashboard with 10 widgets organized in sections:
1. **Header**: Environment and timestamp
2. **Lambda Invocations & Errors**: Invocations, errors, throttles on dual Y-axis
3. **Lambda Duration**: Average, p99, max duration with alarm threshold annotations
4. **Lambda Concurrent Executions**: With alarm threshold line
5. **API Gateway Requests & Errors**: Total requests, 4xx, 5xx errors
6. **API Gateway Latency**: Integration latency and total latency with p99
7. **DynamoDB Consumed Capacity**: Read and write capacity units
8. **DynamoDB Errors & Throttles**: System errors, user errors, read/write throttles
9. **Lambda Error Rate**: Metric math showing error percentage with alarm threshold

### Log Metric Filters

- **Lambda Error Pattern**: Automatically detects ERROR-level log entries and creates custom metric

### SNS Notifications

- **SNS Topic**: `{env}-health-check-alarms`
- **Email Subscription**: Configured via `alarm_email` variable
- **Alarm Actions**: All alarms notify on ALARM state
- **OK Actions**: All alarms notify on OK state (recovery notifications)

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  environment            = "prod"
  lambda_function_name   = "prod-health-check-function"
  lambda_timeout         = 30
  lambda_log_group_name  = "/aws/lambda/prod-health-check-function"
  api_id                 = "abc123xyz"
  dynamodb_table_name    = "prod-health-check-table"
  alarm_email            = "ops-team@example.com"

  # Optional: Override default thresholds
  lambda_error_rate_threshold            = 5
  lambda_duration_threshold_percentage   = 80
  api_5xx_threshold                      = 5
  api_4xx_threshold                      = 20
  api_latency_p99_threshold_ms           = 2000

  tags = {
    Project = "health-check"
    Team    = "platform"
  }
}
```

## Environment-Specific Thresholds

The module supports different thresholds for different environments. The root module (`terraform/main.tf`) demonstrates this pattern:

- **Production**: Stricter thresholds (5% error rate, 80% timeout, 2s latency)
- **Staging**: Relaxed thresholds (10% error rate, 90% timeout, 3s latency)

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `environment` | string | Environment name (e.g., prod, staging) |
| `lambda_function_name` | string | Name of the Lambda function to monitor |
| `lambda_timeout` | number | Lambda function timeout in seconds |
| `lambda_log_group_name` | string | Name of the Lambda CloudWatch log group |
| `api_id` | string | ID of the API Gateway to monitor |
| `dynamodb_table_name` | string | Name of the DynamoDB table to monitor |
| `alarm_email` | string | Email address for alarm notifications |

### Optional Variables (with defaults)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `lambda_error_rate_threshold` | number | 5 | Lambda error rate threshold percentage (0-100) |
| `lambda_duration_threshold_percentage` | number | 80 | Lambda duration threshold as % of timeout |
| `api_5xx_threshold` | number | 5 | API Gateway 5xx error count threshold |
| `api_4xx_threshold` | number | 20 | API Gateway 4xx error count threshold |
| `api_latency_p99_threshold_ms` | number | 2000 | API Gateway p99 latency threshold in ms |
| `tags` | map(string) | {} | Tags to apply to monitoring resources |

## Outputs

| Output | Description |
|--------|-------------|
| `sns_topic_arn` | ARN of the SNS topic for alarms |
| `dashboard_name` | Name of the CloudWatch dashboard |
| `dashboard_url` | Direct URL to the CloudWatch dashboard |
| `alarm_arns` | Map of all CloudWatch alarm ARNs |
| `log_metric_filter_name` | Name of the Lambda error log metric filter |

## Alarm Design Best Practices

This module implements CloudWatch alarm best practices:

1. **Datapoints to Alarm**: Uses `datapoints_to_alarm` with `evaluation_periods` to reduce false positives (e.g., 2 out of 3 datapoints)
2. **Appropriate Periods**: 60s for fast-changing metrics (errors), 300s for trends (latency)
3. **OK Actions**: All alarms send recovery notifications
4. **Treat Missing Data**: Set to `notBreaching` for sporadic metrics to avoid false alarms during low traffic
5. **Alarm Descriptions**: Include investigation hints and threshold explanations
6. **Severity Tags**: All alarms tagged with severity (critical/warning) for routing
7. **Metric Math**: Uses metric math for calculated metrics (error rate percentage)
8. **Extended Statistics**: Uses p99 for latency (not average) to catch tail latency
9. **Composite Alarms**: Single alarm for overall service health
10. **Dashboard Annotations**: Alarm thresholds shown as annotation lines on graphs

## Cost Estimate

Per environment:
- **CloudWatch Alarms**: 13 alarms × $0.10 = $1.30/month
- **Composite Alarm**: 1 alarm × $0.50 = $0.50/month
- **Dashboard**: Free (first 3 dashboards)
- **Custom Metric**: 1 metric × $0.30 = $0.30/month (LambdaErrorLogCount)
- **CloudWatch Logs**: Varies by volume (~$1.50/month for 1GB/day with 30-day retention)

**Total**: ~$4/month per environment

## Runbook

Detailed incident response procedures are available in [RUNBOOK.md](./RUNBOOK.md).

Each alarm includes:
- Severity level
- What the alarm means
- Likely causes
- Investigation steps with CLI commands
- Remediation procedures
- Escalation criteria

## Architecture Decisions

### Why Log Metric Filters?
- Captures application-level errors that might not trigger Lambda errors metric
- Allows monitoring of specific error patterns (e.g., ERROR log level)
- Custom namespace prevents collision with AWS metrics

### Why Composite Alarm?
- Single alert for overall service health
- Reduces alert fatigue (one critical alert vs. multiple)
- Easy to add to PagerDuty/OpsGenie for on-call

### Why p99 for Duration/Latency?
- Average hides tail latency issues affecting some users
- p99 catches worst-case scenarios
- Better indicator of actual user experience

### Why Environment-Specific Thresholds?
- Production needs stricter monitoring
- Staging/dev can tolerate higher error rates during testing
- Reduces false positives in non-prod environments

### Why OK Actions?
- Recovery notifications are as important as alerts
- Helps teams know when to stop investigating
- Useful for incident timelines and post-mortems

## Integration Examples

### Slack Notifications (via AWS Chatbot)

```hcl
resource "aws_chatbot_slack_channel_configuration" "monitoring" {
  configuration_name = "${var.environment}-monitoring-slack"
  slack_workspace_id = "T1234567890"
  slack_channel_id   = "C1234567890"

  sns_topic_arns = [module.monitoring.sns_topic_arn]

  iam_role_arn = aws_iam_role.chatbot.arn

  guardrail_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  ]
}
```

### PagerDuty Integration

```hcl
resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = module.monitoring.sns_topic_arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/${var.pagerduty_integration_key}/enqueue"

  filter_policy = jsonencode({
    Severity = ["critical"]
  })
}
```

### Lambda Function for Custom Notifications

```hcl
resource "aws_sns_topic_subscription" "custom_notifications" {
  topic_arn = module.monitoring.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alarm_processor.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alarm_processor.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.monitoring.sns_topic_arn
}
```

## Maintenance

### Adding New Alarms

1. Add alarm resource to `main.tf`
2. Update `outputs.tf` to include new alarm ARN
3. Add runbook section to `RUNBOOK.md`
4. Test alarm by manually putting it in ALARM state:
   ```bash
   aws cloudwatch set-alarm-state \
     --alarm-name {env}-new-alarm \
     --state-value ALARM \
     --state-reason "Testing alarm notifications"
   ```

### Adjusting Thresholds

Thresholds can be adjusted per environment in the root module or via variables. Monitor alarm history to tune thresholds:

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name {env}-lambda-errors \
  --max-records 50
```

If frequent false positives:
- Increase threshold value
- Increase `datapoints_to_alarm` ratio
- Increase `period` for less sensitive detection

### Testing Alarms

Confirm SNS subscription after deployment:
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn)
```

Test email notifications by triggering a test alarm.

## Troubleshooting

### Email Notifications Not Received

1. Check SNS subscription is confirmed:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn {topic-arn}
   ```
   Status should be "SubscriptionConfirmed" not "PendingConfirmation"

2. Check email spam folder for confirmation email

3. Manually confirm subscription if needed

### Alarm Not Firing

1. Check alarm configuration:
   ```bash
   aws cloudwatch describe-alarms --alarm-names {env}-lambda-errors
   ```

2. Verify metric is publishing data:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Errors \
     --dimensions Name=FunctionName,Value={function-name} \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 60 \
     --statistics Sum
   ```

3. Check `treat_missing_data` setting

### Dashboard Not Showing Data

1. Verify resource names in dashboard widgets match actual resources
2. Check region is correct in widget definitions
3. Confirm IAM permissions for CloudWatch console access

## Related Documentation

- [AWS CloudWatch Alarms Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)
- [CloudWatch Logs Metric Filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
- [Alarm Runbook](./RUNBOOK.md)
