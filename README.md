# Serverless Health Check Application

Production-ready serverless health check application built with AWS Lambda, API Gateway, and DynamoDB, managed via Terraform.

## Architecture

```
API Gateway (HTTP API)
    ↓
Lambda Function (Python 3.12)
    ↓
DynamoDB (PAY_PER_REQUEST)
```

### Components

- **API Gateway v2 (HTTP API)**: Public REST API with throttling and CORS
- **Lambda Function**: Python 3.12 function that validates input and stores requests
- **DynamoDB**: Serverless NoSQL database with KMS encryption and point-in-time recovery
- **KMS**: Customer-managed encryption key for DynamoDB
- **CloudWatch**: Logs, alarms, and dashboard for monitoring
- **SNS**: Email notifications for CloudWatch alarms
- **IAM**: Least-privilege roles with scoped permissions

## Security Features

- **Encryption**: DynamoDB encrypted at rest with customer-managed KMS keys
- **IAM**: Least-privilege policies with NO wildcard (*) resource ARNs
- **Input Validation**: Lambda validates all incoming requests
- **API Throttling**: Configurable rate and burst limits
- **VPC Support**: Optional VPC deployment for Lambda
- **Monitoring**: Comprehensive CloudWatch alarms for errors, latency, and throttling

## Directory Structure

```
.
├── lambda/
│   ├── health_check.py      # Lambda function source code
│   └── requirements.txt      # Python dependencies
└── terraform/
    ├── main.tf              # Root module wiring all components
    ├── variables.tf         # Input variables
    ├── outputs.tf           # Output values
    ├── versions.tf          # Provider version constraints
    ├── backend.tf           # S3 backend configuration
    ├── staging.tfvars       # Staging environment config
    ├── prod.tfvars          # Production environment config
    └── modules/
        ├── api-gateway/     # HTTP API Gateway v2
        ├── dynamodb/        # DynamoDB table with encryption
        ├── iam/             # IAM roles and policies
        ├── kms/             # KMS encryption key
        ├── lambda/          # Lambda function
        └── monitoring/      # CloudWatch alarms and dashboard
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with appropriate credentials
- An S3 bucket for Terraform state (optional, for remote state)
- A DynamoDB table for state locking (optional, for remote state)

## CI/CD Pipeline

The project includes GitHub Actions workflows for automated deployment.

### Workflows

| Workflow | Trigger | Environment |
|----------|---------|-------------|
| `deploy-staging.yml` | Push to `main` (terraform/**, lambda/**) | staging |
| `deploy-prod.yml` | Manual (`workflow_dispatch`) | production |
| `pr-check.yml` | Pull request to `main` | — (validation only) |

### Pipeline Steps

```
Security Scan (tfsec, checkov, pip-audit)
    ↓
Package Lambda (pip install + zip)
    ↓
Terraform Init → Plan → Apply
    ↓
[prod only] Manual Approval Gate
```

### How to Trigger a Staging Deployment

1. Push changes to the `main` branch:
   ```bash
   git push origin main
   ```
2. The `deploy-staging.yml` workflow runs automatically
3. Security scans run first — pipeline fails if HIGH/CRITICAL issues found
4. Lambda is packaged and Terraform applies with `staging.tfvars`

### How to Trigger a Production Deployment

1. Go to **Actions** tab in GitHub
2. Select **Deploy Production** workflow
3. Click **Run workflow** and choose `apply`
4. After the plan step, a reviewer must approve in the `production` environment

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN_STAGING` | IAM role ARN for staging OIDC |
| `AWS_ROLE_ARN_PROD` | IAM role ARN for production OIDC |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state |
| `TF_STATE_LOCK_TABLE` | DynamoDB table for state locking |

### Required GitHub Environments

- `staging` — optional protection rules
- `production` — **must configure required reviewers** for approval gate

See `.github/CICD_SETUP.md` for detailed AWS OIDC setup instructions.

## Deployment (Manual)

### 1. Configure Backend (Optional)

Edit `terraform/backend.tf` and uncomment the S3 backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

### 2. Update tfvars

Edit `staging.tfvars` or `prod.tfvars` to customize:

- `alarm_email`: Email address for CloudWatch alarm notifications
- `aws_region`: AWS region for deployment
- VPC settings if using VPC deployment

### 3. Initialize Terraform

```bash
cd terraform
terraform init
```

### 4. Deploy to Staging

```bash
terraform plan -var-file=staging.tfvars
terraform apply -var-file=staging.tfvars
```

### 5. Deploy to Production

```bash
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Usage

After deployment, Terraform outputs the API endpoint URL:

```bash
terraform output health_check_url
```

### Test the Endpoint

**POST Request:**

```bash
curl -X POST https://your-api-id.execute-api.us-east-1.amazonaws.com/health \
  -H "Content-Type: application/json" \
  -d '{"payload": "test data"}'
```

**Response:**

```json
{
  "status": "healthy",
  "message": "Request processed and saved.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000",
  "environment": "staging"
}
```

**Error Response (missing payload):**

```json
{
  "error": "Bad Request",
  "message": "Request body must contain 'payload' field"
}
```

## Monitoring

### CloudWatch Dashboard

View metrics dashboard:

```bash
# Get dashboard name
terraform output cloudwatch_dashboard_name

# Open in AWS Console
aws cloudwatch get-dashboard --dashboard-name <name>
```

### Alarms

The following alarms are configured and send notifications to the specified email:

**Lambda Alarms:**
- Errors > 0 (critical)
- Duration > 5000ms (warning)
- Throttles > 0 (critical)

**API Gateway Alarms:**
- 5xx errors > 0 (critical)
- 4xx errors > 10 in 5 minutes (warning)
- p99 latency > 1000ms (warning)

**DynamoDB Alarms:**
- System errors > 0 (critical)
- Throttled requests > 5 (warning)

### Logs

View Lambda logs:

```bash
aws logs tail /aws/lambda/staging-health-check-function --follow
```

## Terraform Outputs

| Output | Description |
|--------|-------------|
| `health_check_url` | Full URL for the health check endpoint |
| `api_endpoint` | API Gateway base endpoint |
| `lambda_function_name` | Lambda function name |
| `lambda_function_arn` | Lambda function ARN |
| `dynamodb_table_name` | DynamoDB table name |
| `kms_key_alias` | KMS key alias |
| `cloudwatch_dashboard_name` | CloudWatch dashboard name |
| `sns_topic_arn` | SNS topic ARN for alarms |

## Environment-Specific Configuration

### Staging
- Memory: 128 MB
- Timeout: 10 seconds
- Log retention: 14 days
- API rate limit: 100 req/s
- API burst limit: 50 req/s

### Production
- Memory: 256 MB
- Timeout: 30 seconds
- Log retention: 90 days
- API rate limit: 1000 req/s
- API burst limit: 500 req/s

## Cost Optimization

- **DynamoDB**: PAY_PER_REQUEST billing (no idle costs)
- **Lambda**: Efficient memory allocation per environment
- **API Gateway**: HTTP API (cheaper than REST API)
- **CloudWatch**: Appropriate log retention per environment

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file=staging.tfvars
```

## Development

### Local Testing

Install Python dependencies:

```bash
cd lambda
pip install -r requirements.txt
```

Test Lambda locally:

```python
from health_check import lambda_handler
import os

os.environ['TABLE_NAME'] = 'test-table'
os.environ['ENVIRONMENT'] = 'local'

event = {
    'body': '{"payload": "test"}'
}

response = lambda_handler(event, None)
print(response)
```

## Security Best Practices

1. **No Hardcoded Secrets**: All sensitive data via environment variables
2. **Least Privilege IAM**: Scoped permissions to specific resources
3. **Encryption**: KMS customer-managed keys for data at rest
4. **Input Validation**: All inputs validated before processing
5. **Throttling**: API Gateway rate limiting enabled
6. **Monitoring**: Comprehensive alarms for security events
7. **Audit Trail**: CloudWatch logs for all requests

## Troubleshooting

### Lambda Errors

Check CloudWatch logs:

```bash
aws logs tail /aws/lambda/staging-health-check-function --follow
```

### DynamoDB Access Denied

Verify IAM role has correct permissions:

```bash
aws iam get-role-policy \
  --role-name staging-health-check-lambda-role \
  --policy-name staging-lambda-dynamodb-policy
```

### API Gateway 403 Errors

Check Lambda permissions:

```bash
aws lambda get-policy \
  --function-name staging-health-check-function
```

## Design Choices & Assumptions

1. **HTTP API (v2) over REST API (v1)**: Lower cost, lower latency, sufficient for this use case
2. **PAY_PER_REQUEST DynamoDB**: No idle costs, auto-scales, ideal for variable traffic
3. **Python 3.12**: Latest stable runtime, excellent boto3 support, fast cold starts
4. **Modular Terraform**: Each resource type is a separate module for reusability and testability
5. **KMS CMK over AWS-managed keys**: More control over key rotation and access policies
6. **OIDC over static credentials**: No long-lived secrets in GitHub — IAM roles assumed via federated identity
7. **Separate staging/prod tfvars**: Simple, explicit environment configuration without workspaces complexity
8. **Security-first pipeline**: IaC scanning (tfsec + checkov) and dependency scanning (pip-audit) run before any deployment
9. **Manual approval for prod**: Prevents accidental production changes; requires human review
10. **Composite CloudWatch alarm**: Single "service health" alarm aggregates all critical alarms for simplified paging

## Contributing

1. Follow Terraform best practices
2. Update module documentation
3. Test in staging before production
4. Run `terraform fmt` before committing
5. Update this README for significant changes

## License

MIT
