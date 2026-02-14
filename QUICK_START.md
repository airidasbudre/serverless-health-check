# Quick Start Guide

5-minute guide to deploy the serverless health check application.

## Prerequisites

```bash
# Verify installations
terraform version  # Should be >= 1.5
aws --version      # AWS CLI
python3 --version  # Python 3.x
```

## Step 1: Configure

Edit `terraform/staging.tfvars`:

```bash
cd terraform
nano staging.tfvars
```

Update:
```hcl
alarm_email = "your-email@example.com"  # Change this!
```

## Step 2: Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file=staging.tfvars

# Deploy (takes ~2-3 minutes)
terraform apply -var-file=staging.tfvars
```

Type `yes` when prompted.

## Step 3: Confirm SNS Subscription

Check your email and click the confirmation link from AWS SNS.

## Step 4: Test

```bash
# Get the API URL
terraform output health_check_url

# Test the endpoint
curl -X POST $(terraform output -raw health_check_url) \
  -H "Content-Type: application/json" \
  -d '{"payload": "Hello World"}'
```

Expected response:
```json
{
  "status": "healthy",
  "message": "Request processed and saved.",
  "request_id": "uuid-here",
  "environment": "staging"
}
```

## Step 5: View Dashboard

```bash
# Get dashboard name
terraform output cloudwatch_dashboard_name

# Open in AWS Console
# Navigate to: CloudWatch > Dashboards > [dashboard-name]
```

## Using Make (Alternative)

```bash
# Deploy everything
make deploy-staging

# Test endpoint
make test-staging

# View outputs
make outputs-staging
```

## Common Commands

```bash
# View all outputs
terraform output

# View logs
aws logs tail /aws/lambda/staging-health-check-function --follow

# Check DynamoDB data
aws dynamodb scan --table-name staging-requests-db --limit 5

# Destroy everything
terraform destroy -var-file=staging.tfvars
```

## Troubleshooting

**Problem**: Terraform init fails

**Solution**: Configure backend first or disable it:
```bash
# Edit backend.tf and comment out the backend block, or:
terraform init -backend=false
```

**Problem**: API returns 403

**Solution**: Check Lambda permission:
```bash
aws lambda get-policy --function-name staging-health-check-function
```

**Problem**: Can't find resources

**Solution**: Verify deployment completed:
```bash
terraform state list
```

## Next Steps

- Review [README.md](README.md) for detailed documentation
- See [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment
- Check [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for architecture details

## Production Deployment

When ready for production:

```bash
# Update prod.tfvars
nano prod.tfvars

# Deploy to production
terraform init -backend-config=backend-config-prod.hcl
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

Or:
```bash
make deploy-prod
```
