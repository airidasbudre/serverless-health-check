# CloudWatch Monitoring Runbook

## Overview
This runbook provides investigation and remediation steps for all CloudWatch alarms configured for the Health Check Service.

**Dashboard URL**: Check Terraform outputs for `dashboard_url`
**SNS Topic**: Alerts are sent via SNS topic `{env}-health-check-alarms`

---

## Lambda Alarms

### Alarm: lambda-errors
**Severity**: Critical
**Threshold**: Any errors (2 out of 3 datapoints)

**What it means**: The Lambda function is throwing exceptions or encountering unhandled errors.

**Likely causes**:
- Code bugs or unhandled exceptions
- Missing or invalid environment variables
- Permission issues accessing DynamoDB
- Malformed requests from API Gateway
- Timeout issues causing abrupt termination

**Investigation steps**:
1. Check CloudWatch Logs for error details:
   ```bash
   aws logs tail /aws/lambda/{env}-health-check-function --follow --format short
   ```
2. Review recent code deployments (check if error started after a deployment)
3. Check Lambda metrics in CloudWatch dashboard for patterns
4. Review X-Ray traces if enabled for detailed error context
5. Check Lambda environment variables are correctly set:
   ```bash
   aws lambda get-function-configuration --function-name {env}-health-check-function
   ```

**Remediation**:
- **Immediate**: Rollback to last known good deployment if recent change caused errors
- **Short-term**: Add error handling/logging to identify root cause
- **Long-term**:
  - Implement input validation
  - Add retry logic with exponential backoff for transient failures
  - Enable X-Ray for better visibility

**Escalation**: If unresolved in 15 minutes, escalate to on-call engineer

---

### Alarm: lambda-error-rate
**Severity**: Warning
**Threshold**: Error rate > 5% (prod) / 10% (staging)

**What it means**: A significant percentage of Lambda invocations are failing.

**Likely causes**:
- Widespread input validation failures
- External dependency (DynamoDB) experiencing issues
- Partial outage affecting subset of requests
- Cold start timeouts

**Investigation steps**:
1. Check error rate trend in dashboard - is it increasing or stable?
2. Compare error count to total invocations - how many actual errors?
3. Check if errors correlate with specific API endpoints or request patterns
4. Review Lambda concurrent executions - are we hitting limits?
5. Check DynamoDB throttle alarms - could be downstream issue

**Remediation**:
- If correlated with DynamoDB throttles: increase DynamoDB capacity
- If correlated with concurrent executions: increase Lambda reserved concurrency
- If input validation errors: review API Gateway request validation

**Escalation**: If error rate continues to climb, escalate immediately

---

### Alarm: lambda-duration
**Severity**: Warning
**Threshold**: p99 duration > 80% of timeout (prod) / 90% (staging)

**What it means**: Lambda functions are taking longer than expected, approaching timeout.

**Likely causes**:
- DynamoDB query performance degradation
- Cold starts taking longer
- Increased data volume in DynamoDB
- Memory constraints causing CPU throttling
- Network latency to DynamoDB

**Investigation steps**:
1. Check Lambda duration metrics in dashboard (average vs p99 vs max)
2. Review DynamoDB query latency
3. Check Lambda memory utilization (in logs or CloudWatch metrics)
4. Review recent changes to Lambda code or DynamoDB schema
5. Check for cold starts:
   ```bash
   aws logs filter-pattern /aws/lambda/{env}-health-check-function --filter-pattern "REPORT" --start-time 1h
   ```

**Remediation**:
- **If memory-bound**: Increase Lambda memory (also increases CPU)
- **If DynamoDB latency**:
  - Review query patterns and add indexes if needed
  - Consider DynamoDB DAX for caching
  - Check if on-demand billing helps with burst capacity
- **If cold starts**:
  - Implement provisioned concurrency
  - Optimize initialization code
  - Reduce deployment package size

**Escalation**: If duration approaches timeout and causes errors, escalate immediately

---

### Alarm: lambda-throttles
**Severity**: Critical
**Threshold**: Any throttles

**What it means**: Lambda is rejecting invocations due to concurrency limits.

**Likely causes**:
- Concurrent execution limit reached (default: 1000 per region)
- Reserved concurrency set too low for this function
- Traffic spike exceeding capacity
- Slow function execution causing backlog

**Investigation steps**:
1. Check current concurrent executions in dashboard
2. Review account-level concurrency limits:
   ```bash
   aws lambda get-account-settings
   ```
3. Check function-level reserved concurrency:
   ```bash
   aws lambda get-function-concurrency --function-name {env}-health-check-function
   ```
4. Review recent traffic patterns in API Gateway metrics
5. Check if other Lambda functions in account are consuming concurrency

**Remediation**:
- **Immediate**:
  - Request concurrency limit increase from AWS Support
  - Review and remove reserved concurrency from less critical functions
- **Short-term**: Implement exponential backoff in API clients
- **Long-term**:
  - Optimize function to reduce execution time
  - Consider SQS queue to buffer requests
  - Use provisioned concurrency for predictable workloads

**Escalation**: Throttles impact availability - escalate immediately

---

### Alarm: lambda-concurrent-executions
**Severity**: Warning
**Threshold**: > 900 concurrent executions

**What it means**: Concurrent executions approaching account limit (usually 1000).

**Likely causes**:
- Sustained high traffic
- Function duration increased, causing more concurrent executions
- Traffic spike

**Investigation steps**:
1. Check concurrent executions trend - is it steady or spiking?
2. Review invocation count and duration metrics
3. Calculate expected concurrency: (invocations/sec × duration in sec)
4. Check API Gateway request count for traffic patterns

**Remediation**:
- Monitor closely - if continues to climb, will trigger throttles
- Request concurrency limit increase proactively
- Review if function duration can be optimized
- Consider implementing API throttling at API Gateway level

**Escalation**: If trending toward limit and traffic not decreasing, escalate

---

### Alarm: lambda-error-logs
**Severity**: Warning
**Threshold**: > 5 ERROR log entries in 5 minutes

**What it means**: Application is logging ERROR-level messages.

**Likely causes**:
- Application errors being properly logged but not causing Lambda errors
- Gracefully handled exceptions
- Warning conditions that should be investigated

**Investigation steps**:
1. Review CloudWatch Logs for ERROR patterns:
   ```bash
   aws logs filter-pattern /aws/lambda/{env}-health-check-function --filter-pattern "ERROR"
   ```
2. Identify error messages and stack traces
3. Check if errors are correlated with specific request types

**Remediation**:
- Investigate root cause of logged errors
- Fix underlying issues or adjust logging level if appropriate
- Add monitoring for specific error patterns if needed

**Escalation**: If errors indicate data corruption or security issues, escalate immediately

---

## API Gateway Alarms

### Alarm: api-5xx-errors
**Severity**: Critical
**Threshold**: > 5 errors in 3 minutes (2 of 3 datapoints)

**What it means**: API Gateway or Lambda backend is returning 5xx errors.

**Likely causes**:
- Lambda function errors (check lambda-errors alarm)
- Lambda function timeouts
- Permission issues (Lambda execution role)
- API Gateway configuration issues
- Lambda function cold start timeouts

**Investigation steps**:
1. Check if lambda-errors alarm is also firing
2. Review API Gateway logs (if enabled):
   ```bash
   # Enable API Gateway CloudWatch logs first if not already enabled
   aws apigatewayv2 get-stage --api-id {api-id} --stage-name $default
   ```
3. Check Lambda function status:
   ```bash
   aws lambda get-function --function-name {env}-health-check-function
   ```
4. Review API Gateway integration timeout settings
5. Check for Lambda permission issues in CloudTrail

**Remediation**:
- **If Lambda errors**: Follow lambda-errors runbook
- **If Lambda timeouts**: Increase Lambda timeout or optimize code
- **If permissions**: Update Lambda execution role or resource-based policy
- **If API Gateway issue**: Review API Gateway configuration and integration settings

**Escalation**: 5xx errors indicate service unavailability - escalate immediately

---

### Alarm: api-4xx-errors
**Severity**: Warning
**Threshold**: > 20 errors in 5 minutes (prod) / > 50 (staging)

**What it means**: Clients are sending invalid requests.

**Likely causes**:
- Client application bugs
- Invalid authentication/authorization
- Malformed request payloads
- Missing required parameters
- API documentation out of sync with implementation

**Investigation steps**:
1. Check API Gateway access logs for specific 4xx status codes (400, 401, 403, 404)
2. Review request patterns - are errors from specific IPs or user agents?
3. Check if errors correlate with recent API changes
4. Review API Gateway request validation configuration
5. Sample failed request payloads

**Remediation**:
- **If 400 errors**: Review API documentation, add request validation
- **If 401/403 errors**: Check authentication/authorization configuration
- **If 404 errors**: Check API routes are correctly configured
- **If widespread**: May indicate client bug or API breaking change - notify API consumers

**Escalation**: If 4xx rate is abnormally high, may indicate attack or client outage - escalate

---

### Alarm: api-latency-p99
**Severity**: Warning
**Threshold**: p99 > 2000ms (prod) / 3000ms (staging)

**What it means**: 99th percentile of requests are slow.

**Likely causes**:
- Lambda duration issues (check lambda-duration alarm)
- API Gateway throttling overhead
- Cold starts
- DynamoDB query latency

**Investigation steps**:
1. Check Lambda duration metrics - is latency from Lambda?
2. Review API Gateway Latency vs IntegrationLatency in dashboard
   - High Latency but normal IntegrationLatency = API Gateway overhead
   - High IntegrationLatency = Lambda/backend issue
3. Check for cold starts in Lambda logs
4. Review DynamoDB performance metrics

**Remediation**:
- Follow lambda-duration runbook if Lambda is slow
- If API Gateway overhead: review throttling settings, check quotas
- If cold starts: implement provisioned concurrency
- Consider caching at API Gateway or CloudFront level

**Escalation**: If latency continues to degrade, may impact user experience - escalate

---

## DynamoDB Alarms

### Alarm: dynamodb-system-errors
**Severity**: Critical
**Threshold**: Any system errors

**What it means**: DynamoDB service-side errors (AWS infrastructure issue).

**Likely causes**:
- AWS service disruption
- DynamoDB control plane issues
- Rare AWS infrastructure failures

**Investigation steps**:
1. Check AWS Service Health Dashboard:
   ```
   https://status.aws.amazon.com/
   ```
2. Review DynamoDB service quotas and limits
3. Check if errors are transient or sustained
4. Review CloudTrail for any DynamoDB API errors

**Remediation**:
- **Immediate**: Implement retry logic in application (exponential backoff)
- **Short-term**: Monitor AWS Service Health for updates
- **Long-term**: Ensure application has proper retry and circuit breaker patterns

**Escalation**: Open AWS Support ticket immediately - this is an AWS issue

---

### Alarm: dynamodb-read-throttles
**Severity**: Warning
**Threshold**: > 5 throttled read requests in 5 minutes

**What it means**: DynamoDB read capacity exceeded.

**Likely causes**:
- Read capacity provisioned too low (if provisioned mode)
- Traffic spike exceeding on-demand capacity
- Hot partition key causing throttling
- Inefficient query patterns (scans instead of queries)

**Investigation steps**:
1. Check DynamoDB table billing mode (provisioned vs on-demand):
   ```bash
   aws dynamodb describe-table --table-name {env}-health-check-table
   ```
2. Review consumed read capacity in dashboard
3. Check for hot partitions (all reads going to same partition key)
4. Review access patterns in application logs
5. Check if throttling is during specific time periods

**Remediation**:
- **If provisioned mode**:
  - Increase read capacity units
  - Consider switching to on-demand mode
  - Enable auto-scaling if not already enabled
- **If on-demand mode**:
  - Review for hot partition keys
  - Implement caching (ElastiCache/DAX)
  - Optimize query patterns
- **If hot partition**:
  - Review partition key design
  - Consider composite partition key

**Escalation**: If sustained throttling impacts service, escalate

---

### Alarm: dynamodb-write-throttles
**Severity**: Warning
**Threshold**: > 5 throttled write requests in 5 minutes

**What it means**: DynamoDB write capacity exceeded.

**Likely causes**:
- Write capacity provisioned too low (if provisioned mode)
- Traffic spike exceeding on-demand capacity
- Hot partition key causing throttling
- Batch writes without exponential backoff

**Investigation steps**:
1. Check DynamoDB table billing mode
2. Review consumed write capacity in dashboard
3. Check for hot partitions (all writes going to same partition key)
4. Review write patterns - are they batched efficiently?
5. Check for GSI (Global Secondary Index) throttling

**Remediation**:
- **If provisioned mode**:
  - Increase write capacity units
  - Consider switching to on-demand mode
  - Enable auto-scaling if not already enabled
- **If on-demand mode**:
  - Review for hot partition keys
  - Implement write buffering/batching
  - Use exponential backoff on retries
- **If hot partition**: Review partition key design
- **If GSI throttling**: Increase GSI capacity separately

**Escalation**: If sustained throttling causes data loss, escalate immediately

---

## Composite Alarm

### Alarm: service-health-composite
**Severity**: Critical
**Threshold**: When any critical alarm fires

**What it means**: Overall service health is degraded.

**Likely causes**: See individual alarm runbooks

**Investigation steps**:
1. Check dashboard for all alarm states
2. Identify which critical alarms are firing:
   - lambda-errors
   - lambda-throttles
   - api-5xx-errors
   - dynamodb-system-errors
3. Follow runbook for each firing alarm

**Remediation**: Follow individual alarm remediation steps

**Escalation**: Composite alarm indicates service impact - page on-call immediately

---

## General Response Procedures

### Initial Response (First 5 minutes)
1. Acknowledge alert
2. Check CloudWatch Dashboard for overall service health
3. Identify which specific alarms are firing
4. Check AWS Service Health Dashboard for any ongoing incidents
5. Review recent deployments or changes

### Investigation (Next 15 minutes)
1. Follow specific alarm runbook
2. Collect relevant logs and metrics
3. Identify root cause or immediate trigger
4. Determine if issue is transient or sustained

### Resolution
1. Implement immediate remediation if available
2. Monitor for recovery
3. Document incident timeline and resolution
4. Schedule post-mortem if significant impact

### Post-Incident
1. Update runbook if new patterns discovered
2. Review alarm thresholds if false positive
3. Implement long-term fixes to prevent recurrence
4. Update monitoring if gaps identified

---

## Useful Commands

### Check Lambda Function Status
```bash
aws lambda get-function --function-name {env}-health-check-function
```

### Tail Lambda Logs
```bash
aws logs tail /aws/lambda/{env}-health-check-function --follow --format short
```

### Query Lambda Logs (Last 1 hour)
```bash
aws logs filter-pattern /aws/lambda/{env}-health-check-function \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

### Check DynamoDB Table Status
```bash
aws dynamodb describe-table --table-name {env}-health-check-table
```

### Check Current Alarms
```bash
aws cloudwatch describe-alarms --state-value ALARM
```

### Get Alarm History
```bash
aws cloudwatch describe-alarm-history \
  --alarm-name {env}-lambda-errors \
  --max-records 10
```

### Check API Gateway Metrics
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApiGateway \
  --metric-name 5XXError \
  --dimensions Name=ApiId,Value={api-id} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

---

## Cost Optimization Notes

**CloudWatch Costs**:
- Alarms: $0.10 per alarm per month (13 alarms = $1.30/month)
- Composite alarms: $0.50 per alarm per month
- Dashboard: Free (first 3), $3/month after
- Logs storage: Varies by retention period (30 days default)
- Metrics: Standard metrics free, custom metrics $0.30 per metric/month
- Log Insights queries: $0.005 per GB scanned

**Current Setup Estimated Cost** (per environment):
- Alarms: ~$2/month
- Dashboard: Free (only 1 dashboard)
- Logs (assuming 1GB/day, 30-day retention): ~$1.50/month
- Custom metric (LambdaErrorLogCount): ~$0.30/month
- **Total**: ~$4/month per environment

To reduce costs:
- Reduce log retention for non-prod (7-14 days)
- Remove alarms in dev/test environments
- Use metric math instead of custom metrics where possible
