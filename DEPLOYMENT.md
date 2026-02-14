# Deployment Guide

Complete guide for deploying the serverless health check application to AWS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Staging Deployment](#staging-deployment)
4. [Production Deployment](#production-deployment)
5. [Verification](#verification)
6. [Rollback](#rollback)

## Prerequisites

### Required Tools

- Terraform >= 1.5.0
- AWS CLI >= 2.0
- Python 3.12 (for local testing)
- jq (optional, for parsing JSON outputs)

### AWS Credentials

Configure AWS CLI with appropriate credentials:

```bash
aws configure
```

Or use environment variables:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### IAM Permissions

Your AWS user/role needs permissions to create:
- Lambda functions
- API Gateway HTTP APIs
- DynamoDB tables
- KMS keys
- IAM roles and policies
- CloudWatch alarms and dashboards
- SNS topics
- CloudWatch log groups

## Initial Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd claude_agents
```

### 2. Configure Backend (Optional but Recommended)

Create an S3 bucket for Terraform state:

```bash
# Create bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Update Backend Configuration

Edit `terraform/backend-config-staging.hcl` and `terraform/backend-config-prod.hcl`:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "staging/health-check/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
```

### 4. Update Environment Variables

Edit `terraform/staging.tfvars`:

```hcl
alarm_email = "your-team@example.com"
```

Edit `terraform/prod.tfvars`:

```hcl
alarm_email = "your-team@example.com"
```

## Staging Deployment

### 1. Initialize Terraform

```bash
cd terraform

# With backend configuration
terraform init -backend-config=backend-config-staging.hcl

# Or without remote backend
terraform init
```

### 2. Validate Configuration

```bash
terraform validate
```

### 3. Plan Deployment

```bash
terraform plan -var-file=staging.tfvars -out=staging.tfplan
```

Review the plan output carefully. You should see:
- 1 API Gateway HTTP API
- 1 Lambda function
- 1 DynamoDB table
- 1 KMS key
- Multiple IAM roles and policies
- 8 CloudWatch alarms
- 1 CloudWatch dashboard
- 1 SNS topic

### 4. Apply Configuration

```bash
terraform apply staging.tfplan
```

This will create all resources. The process takes approximately 2-3 minutes.

### 5. Confirm SNS Subscription

Check your email for an SNS subscription confirmation from AWS. Click the confirmation link to receive alarm notifications.

### 6. Capture Outputs

```bash
# Save all outputs
terraform output -json > staging-outputs.json

# Get API endpoint
terraform output health_check_url
```

## Production Deployment

### 1. Initialize Terraform for Production

```bash
# Clean existing state (if switching from staging)
rm -rf .terraform/

# Initialize with production backend
terraform init -backend-config=backend-config-prod.hcl
```

### 2. Create Production Workspace (Optional)

```bash
terraform workspace new prod
```

### 3. Plan Production Deployment

```bash
terraform plan -var-file=prod.tfvars -out=prod.tfplan
```

### 4. Apply Production Configuration

```bash
terraform apply prod.tfplan
```

### 5. Verify Production Deployment

```bash
# Get production endpoint
terraform output health_check_url

# Test production endpoint
curl -X POST $(terraform output -raw health_check_url) \
  -H "Content-Type: application/json" \
  -d '{"payload": "production test"}'
```

## Verification

### Test Health Check Endpoint

```bash
# Get endpoint URL
API_URL=$(terraform output -raw health_check_url)

# Test POST request
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"payload": "test data"}' | jq

# Expected response:
# {
#   "status": "healthy",
#   "message": "Request processed and saved.",
#   "request_id": "uuid-here",
#   "environment": "staging"
# }
```

### Test Input Validation

```bash
# Test missing payload field
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"invalid": "field"}' | jq

# Expected error:
# {
#   "error": "Bad Request",
#   "message": "Request body must contain 'payload' field"
# }
```

### Verify DynamoDB Data

```bash
# Get table name
TABLE_NAME=$(terraform output -raw dynamodb_table_name)

# Scan table (use carefully in production)
aws dynamodb scan --table-name $TABLE_NAME --limit 5
```

### Check Lambda Logs

```bash
# Get function name
FUNCTION_NAME=$(terraform output -raw lambda_function_name)

# Tail logs
aws logs tail /aws/lambda/$FUNCTION_NAME --follow
```

### View CloudWatch Dashboard

```bash
# Get dashboard name
DASHBOARD_NAME=$(terraform output -raw cloudwatch_dashboard_name)

# Open in browser (macOS)
open "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=$DASHBOARD_NAME"
```

### Test CloudWatch Alarms

Trigger an error to test alarms:

```bash
# Send invalid JSON
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d 'invalid json'

# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names staging-lambda-errors
```

## Rollback

### Rollback to Previous State

If you need to rollback:

```bash
# View state versions (if using S3 backend)
aws s3api list-object-versions \
  --bucket your-terraform-state-bucket \
  --prefix staging/health-check/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket your-terraform-state-bucket \
  --key staging/health-check/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup

# Apply previous state
cp terraform.tfstate.backup terraform.tfstate
terraform apply -var-file=staging.tfvars
```

### Destroy Resources

To completely remove all resources:

```bash
# Staging
terraform destroy -var-file=staging.tfvars

# Production
terraform destroy -var-file=prod.tfvars
```

## Troubleshooting

### Issue: Terraform Init Fails

**Error**: "Failed to get existing workspaces"

**Solution**: Check S3 bucket permissions and verify backend configuration.

```bash
aws s3 ls s3://your-terraform-state-bucket/
```

### Issue: Lambda Function Not Updating

**Error**: "Lambda function code not updated"

**Solution**: The source code hash forces updates. Verify Lambda source files changed:

```bash
cd lambda
ls -la *.py
```

### Issue: API Gateway Returns 403

**Error**: "Forbidden"

**Solution**: Verify Lambda permission for API Gateway:

```bash
aws lambda get-policy --function-name staging-health-check-function
```

### Issue: DynamoDB Access Denied

**Error**: "User is not authorized to perform: dynamodb:PutItem"

**Solution**: Check IAM role policy:

```bash
aws iam get-role-policy \
  --role-name staging-health-check-lambda-role \
  --policy-name staging-lambda-dynamodb-policy
```

### Issue: SNS Email Not Received

**Solution**: Check SNS subscription status:

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn)
```

## Monitoring

### Key Metrics to Watch

1. **Lambda Invocations**: Should match API Gateway requests
2. **Lambda Errors**: Should be zero
3. **Lambda Duration**: Should be < 1 second
4. **API 4xx Errors**: High rate indicates client issues
5. **API 5xx Errors**: Any value indicates server issues
6. **DynamoDB Write Capacity**: Should remain steady

### Setting Up Custom Alarms

Add custom alarms in `terraform/modules/monitoring/main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "${var.environment}-custom-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "YourMetric"
  namespace           = "YourNamespace"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
```

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Use workspaces for environment separation**
3. **Store state remotely in S3 with encryption**
4. **Enable state locking with DynamoDB**
5. **Test in staging before production**
6. **Tag all resources appropriately**
7. **Monitor CloudWatch alarms regularly**
8. **Review IAM permissions quarterly**
9. **Keep Terraform and provider versions updated**
10. **Document all manual changes**

## CI/CD Integration

For automated deployments, use the `terraform-deploy-role`:

```bash
# Assume role in CI/CD pipeline
aws sts assume-role \
  --role-arn $(terraform output -raw iam_terraform_deploy_role_arn) \
  --role-session-name terraform-deploy
```

See CI/CD documentation for GitHub Actions and GitLab CI examples.
