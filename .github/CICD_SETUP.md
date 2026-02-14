# CI/CD Pipeline Setup Guide

This document outlines all required configuration steps to enable the GitHub Actions workflows for the serverless health-check project.

## Overview

Three workflows have been created:
1. **deploy-staging.yml** - Automated staging deployments on push to `main`
2. **deploy-prod.yml** - Manual production deployments with approval gates
3. **pr-check.yml** - Automated validation and security scanning on pull requests

---

## Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with admin access
- Terraform state S3 bucket and DynamoDB table already created
- AWS IAM roles configured for OIDC authentication

---

## 1. AWS OIDC Configuration

### Create GitHub OIDC Identity Provider in AWS

```bash
# Run this once in your AWS account
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Create IAM Roles for GitHub Actions

#### Staging Role (Example)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Attach appropriate permissions policy (example):
- AmazonS3FullAccess (or scoped to Terraform state bucket)
- AmazonDynamoDBFullAccess (or scoped to specific resources)
- AWSLambda_FullAccess
- IAMFullAccess (if creating IAM resources)
- CloudWatchFullAccess
- Custom KMS permissions for encryption keys

#### Production Role

Similar to staging but with stricter condition:
```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:environment:production"
}
```

---

## 2. GitHub Secrets Configuration

### Required Repository Secrets

Navigate to: **Repository Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ROLE_ARN_STAGING` | ARN of IAM role for staging deployments | `arn:aws:iam::123456789012:role/github-actions-staging` |
| `AWS_ROLE_ARN_PROD` | ARN of IAM role for production deployments | `arn:aws:iam::123456789012:role/github-actions-production` |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform state | `your-terraform-state-bucket` |
| `TF_STATE_LOCK_TABLE` | DynamoDB table for state locking | `terraform-state-locks` |

**Note**: If your AWS region is not `us-east-1`, you'll need to update the `AWS_REGION` environment variable in each workflow file.

---

## 3. GitHub Environments Configuration

### Create Staging Environment

1. Go to **Repository Settings → Environments → New environment**
2. Name: `staging`
3. Optional: Add environment secrets (if different from repo secrets)
4. Optional: Add deployment branch restrictions (e.g., only `main`)

### Create Production Environment

1. Go to **Repository Settings → Environments → New environment**
2. Name: `production`
3. **Enable "Required reviewers"**:
   - Add 1-2 team members who must approve production deployments
4. Optional: Add wait timer (e.g., 5 minutes before deployment can proceed)
5. Optional: Add deployment branch restrictions (e.g., only `main`)

This ensures all production deployments require manual approval.

---

## 4. Terraform Backend State Setup

Ensure your S3 bucket and DynamoDB table exist:

### S3 Bucket for State

```bash
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

# Block public access
aws s3api put-public-access-block \
  --bucket your-terraform-state-bucket \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## 5. Workflow Triggers & Usage

### Staging Deployment (Automatic)

**Trigger**: Push to `main` branch (when terraform/ or lambda/ files change)

```bash
git add terraform/main.tf
git commit -m "Update Lambda timeout"
git push origin main
```

The workflow will:
1. Run security scans (tfsec, Checkov, pip-audit)
2. Package Lambda function
3. Run Terraform plan and apply to staging

### Production Deployment (Manual)

**Trigger**: Manual workflow dispatch

1. Go to **Actions → Deploy to Production → Run workflow**
2. Select action: `plan` or `apply`
3. Click "Run workflow"

For `apply`:
- Security scans run first
- Terraform plan is generated and saved as artifact
- Deployment job waits for environment approval
- Approver reviews plan and approves/rejects
- If approved, Terraform apply runs
- Smoke test executes to verify deployment

### Pull Request Checks (Automatic)

**Trigger**: Open/update PR targeting `main` branch

The workflow will:
1. Run Terraform format check, validate, tfsec, Checkov
2. Lint Lambda code with flake8
3. Run pip-audit on dependencies
4. Generate Terraform plan (if AWS credentials available)
5. Comment plan output on the PR

---

## 6. Security Scan Configuration

### tfsec

- Scans Terraform code for security issues
- Configured to fail on `HIGH` and `CRITICAL` findings
- Can skip specific checks by modifying `skip_check` in workflow

### Checkov

- Infrastructure-as-code security scanner
- Configured to fail on `HIGH` severity
- Example skipped checks: `CKV_AWS_116`, `CKV_AWS_173`
- Modify `skip_check` parameter to adjust

### pip-audit

- Scans Python dependencies for known vulnerabilities
- Checks `lambda/requirements.txt`
- Fails pipeline if vulnerable packages found

---

## 7. Troubleshooting

### Common Issues

**Issue**: "Error assuming role"
- **Solution**: Verify OIDC provider is created and role trust policy is correct
- Check the repository name in trust policy matches exactly

**Issue**: "Access Denied" during Terraform operations
- **Solution**: Ensure IAM role has necessary permissions for all resources being created
- Check S3 bucket policy allows the role to access state files

**Issue**: "Backend initialization failed"
- **Solution**: Verify TF_STATE_BUCKET and TF_STATE_LOCK_TABLE secrets are set correctly
- Ensure S3 bucket and DynamoDB table exist in the specified region

**Issue**: Security scans fail with false positives
- **Solution**: Add specific check IDs to `skip_check` parameter in workflow
- Document why each check is skipped for audit purposes

**Issue**: Lambda package too large
- **Solution**: Review dependencies in requirements.txt
- Consider using Lambda layers for large dependencies
- Exclude unnecessary files in zip command

---

## 8. Best Practices

1. **Never commit secrets** - Always use GitHub Secrets
2. **Review Terraform plans** - Always review plan output before approving production deployments
3. **Monitor workflow runs** - Check Actions tab regularly for failures
4. **Keep actions updated** - Dependabot will create PRs for action version updates
5. **Rotate credentials** - Periodically rotate AWS IAM role credentials
6. **Use branch protection** - Require PR reviews and status checks before merging to main
7. **Tag releases** - Create GitHub releases for production deployments
8. **Audit logs** - Review CloudTrail logs for AWS API calls from GitHub Actions

---

## 9. Pipeline Customization

### Modify AWS Region

Update `AWS_REGION` in each workflow file:

```yaml
env:
  AWS_REGION: us-west-2  # Change to your region
```

### Add Additional Environments

Create new workflow file based on `deploy-staging.yml`:
- Update environment name
- Update backend config key
- Update role ARN secret reference

### Skip Security Checks

To skip specific security checks:

```yaml
# tfsec
additional_args: --minimum-severity HIGH --exclude AWS001,AWS002

# Checkov
skip_check: CKV_AWS_116,CKV_AWS_173,CKV2_AWS_5
```

### Add Slack Notifications

Add this step to workflows:

```yaml
- name: Notify Slack
  if: always()
  uses: slackapi/slack-github-action@v1.25.0
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Deployment to ${{ env.ENVIRONMENT }}: ${{ job.status }}"
      }
```

---

## 10. Verification Steps

After setup, verify everything works:

1. **Test PR workflow**:
   ```bash
   git checkout -b test-pr
   echo "# Test" >> terraform/README.md
   git add terraform/README.md
   git commit -m "Test PR workflow"
   git push origin test-pr
   # Create PR and verify checks run
   ```

2. **Test staging deployment**:
   ```bash
   git checkout main
   # Make a small change
   git add .
   git commit -m "Test staging deployment"
   git push origin main
   # Verify deployment completes successfully
   ```

3. **Test production deployment**:
   - Go to Actions → Deploy to Production
   - Select "plan"
   - Verify plan completes and artifact is created
   - Run again with "apply"
   - Verify approval is required
   - Approve and verify deployment succeeds

---

## Support

For issues or questions:
- Check GitHub Actions logs for detailed error messages
- Review Terraform state in S3 bucket
- Check AWS CloudTrail for API call details
- Consult Terraform documentation: https://www.terraform.io/docs
- GitHub Actions documentation: https://docs.github.com/actions
