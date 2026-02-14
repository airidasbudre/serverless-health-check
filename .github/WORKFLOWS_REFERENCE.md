# GitHub Actions Workflows - Quick Reference

## Workflows Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Deploy to Staging | `deploy-staging.yml` | Push to `main` | Automated staging deployment |
| Deploy to Production | `deploy-prod.yml` | Manual (`workflow_dispatch`) | Manual production deployment with approval |
| Pull Request Checks | `pr-check.yml` | Pull requests to `main` | Validation, security scanning, and plan preview |

---

## deploy-staging.yml

### Trigger
- Automatic on push to `main` branch
- Only when files in `terraform/**` or `lambda/**` change

### Jobs Flow
```
security-scan (10 min)
    ├─ tfsec scan (HIGH/CRITICAL)
    ├─ Checkov scan (HIGH)
    └─ pip-audit (dependencies)
         ↓
deploy (20 min)
    ├─ Package Lambda (Python 3.12)
    ├─ Terraform init (staging backend)
    ├─ Terraform validate
    ├─ Terraform plan (staging.tfvars)
    └─ Terraform apply
```

### Concurrency
- Group: `deploy-staging`
- Prevents parallel staging deployments

### Permissions
- `id-token: write` (OIDC)
- `contents: read`

### Required Secrets
- `AWS_ROLE_ARN_STAGING`
- `TF_STATE_BUCKET`
- `TF_STATE_LOCK_TABLE`

### Environment
- `staging` (optional protection rules)

---

## deploy-prod.yml

### Trigger
- Manual only via GitHub Actions UI
- Input: `terraform_action` (plan/apply)

### Jobs Flow
```
security-scan (10 min)
    ├─ tfsec scan (HIGH/CRITICAL)
    ├─ Checkov scan (HIGH)
    └─ pip-audit (dependencies)
         ↓
plan (15 min)
    ├─ Package Lambda
    ├─ Terraform init (prod backend)
    ├─ Terraform validate
    ├─ Terraform plan (prod.tfvars)
    └─ Upload plan artifact
         ↓
deploy (20 min) [only if action=apply]
    ├─ Download plan artifact
    ├─ WAIT FOR APPROVAL (environment gate)
    ├─ Terraform apply
    ├─ Output deployment info
    └─ Smoke test (HTTP 200 check)
```

### Concurrency
- Group: `deploy-production`
- Prevents parallel production deployments

### Permissions
- `id-token: write` (OIDC)
- `contents: read`

### Required Secrets
- `AWS_ROLE_ARN_PROD`
- `TF_STATE_BUCKET`
- `TF_STATE_LOCK_TABLE`

### Environment
- `production` (REQUIRES manual approval)

### Workflow Dispatch Inputs
- `terraform_action`:
  - `plan` - Generate plan only (no deployment)
  - `apply` - Generate plan + deploy (requires approval)

---

## pr-check.yml

### Trigger
- Automatic on pull request to `main`
- Only when files in `terraform/**`, `lambda/**`, or `.github/workflows/**` change

### Jobs Flow
```
validate (15 min)
    ├─ Terraform fmt -check
    ├─ Terraform validate
    ├─ tfsec (soft fail)
    ├─ Checkov (soft fail)
    ├─ flake8 linting (Lambda)
    ├─ pip-audit (soft fail)
    └─ Generate summary
         ↓
plan (15 min) [if credentials available]
    ├─ Package Lambda
    ├─ Terraform init (staging backend)
    ├─ Terraform plan (staging.tfvars)
    └─ Comment plan on PR
```

### Concurrency
- Group: `pr-check-{PR_NUMBER}`
- Cancels in-progress runs for same PR

### Permissions
- `contents: read`
- `pull-requests: write` (for commenting)

### Required Secrets (Optional)
- `AWS_ROLE_ARN_STAGING` (for plan preview)
- `TF_STATE_BUCKET`
- `TF_STATE_LOCK_TABLE`

**Note**: Plan job runs only if AWS credentials configured and PR from same repo

### PR Comment Features
- Terraform plan output
- Auto-updates existing comment
- Truncates if > 60KB

---

## Common Features Across All Workflows

### Security Scanning
- **tfsec**: Terraform security scanner (fails on HIGH/CRITICAL)
- **Checkov**: IaC security scanner (fails on HIGH)
- **pip-audit**: Python dependency vulnerability scanner

### Lambda Packaging
```bash
cd lambda
pip install -r requirements.txt -t package/
cd package
zip -r ../../terraform/lambda.zip . -x "*.pyc" -x "*__pycache__*"
cd ..
zip ../terraform/lambda.zip health_check.py
```

### AWS Authentication
- Uses OIDC (no long-lived credentials)
- Role session names include run ID for traceability

### Terraform Backend Init
```bash
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${ENV}/health-check/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE}" \
  -backend-config="encrypt=true"
```

---

## Action Versions (Pinned)

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | v4 | Checkout repository |
| `actions/setup-python` | v5 | Setup Python 3.12 |
| `hashicorp/setup-terraform` | v3 | Setup Terraform 1.7.0 |
| `aws-actions/configure-aws-credentials` | v4 | AWS OIDC authentication |
| `actions/upload-artifact` | v4 | Upload Terraform plans |
| `actions/download-artifact` | v4 | Download Terraform plans |
| `actions/github-script` | v7 | PR commenting |
| `aquasecurity/tfsec-action` | v1.0.3 | tfsec scanning |
| `bridgecrewio/checkov-action` | v12.2764.0 | Checkov scanning |

---

## Timeouts

| Job | Timeout | Reason |
|-----|---------|--------|
| Security Scan | 10 min | Fast scans |
| Deploy (Staging) | 20 min | Infrastructure provisioning |
| Deploy (Production) | 20 min | Infrastructure provisioning |
| Terraform Plan | 15 min | Read-only operation |
| PR Validation | 15 min | Multiple checks |

---

## Environment Variables

All workflows use:
```yaml
AWS_REGION: us-east-1
TERRAFORM_VERSION: 1.7.0
PYTHON_VERSION: '3.12'
```

Modify in workflow file if your setup differs.

---

## Workflow Outputs

### Staging Deployment
- Terraform outputs in job summary (API URL, Lambda ARN, etc.)

### Production Deployment
- Terraform outputs in job summary
- Smoke test results (HTTP status check)

### PR Checks
- Summary table with check status
- Terraform plan as PR comment
- Lambda dependency list

---

## Troubleshooting Quick Tips

### Workflow Won't Trigger
- Check branch name is exactly `main`
- Check file paths match trigger patterns
- Verify workflow file is in `.github/workflows/`

### Security Scan Failures
- Review tfsec/Checkov output for specific issues
- Add exemptions to `skip_check` if justified
- Fix vulnerabilities in Terraform or dependencies

### Terraform Init Fails
- Verify secrets are set correctly
- Check S3 bucket and DynamoDB table exist
- Ensure IAM role has S3/DynamoDB permissions

### Deployment Fails
- Check IAM role permissions for resource creation
- Review Terraform error in job logs
- Verify tfvars file has correct values

### Production Approval Not Working
- Ensure `production` environment exists in repo settings
- Add required reviewers in environment settings
- Check reviewer has repository access

---

## Manual Workflow Execution

### Trigger Staging Manually (if needed)
```bash
# Make a small change and push
git checkout main
touch terraform/.trigger
git add terraform/.trigger
git commit -m "Trigger staging deployment"
git push origin main
```

### Trigger Production Deployment
1. Go to **Actions** tab
2. Select **Deploy to Production**
3. Click **Run workflow**
4. Select branch: `main`
5. Choose action: `plan` or `apply`
6. Click **Run workflow** button

### Re-run Failed Jobs
1. Go to failed workflow run
2. Click **Re-run failed jobs**
3. Or **Re-run all jobs** to start fresh

---

## Best Practices

1. Always run `plan` before `apply` in production
2. Review Terraform plan artifact before approving
3. Monitor staging deployments before promoting to prod
4. Keep workflow action versions updated
5. Test PR checks on feature branches first
6. Use meaningful commit messages (shown in job logs)
7. Check job summaries for deployment details

---

## Next Steps

After setting up workflows:
1. Configure required secrets (see CICD_SETUP.md)
2. Create GitHub environments with protection rules
3. Test with a sample PR
4. Deploy to staging via push to main
5. Test production deployment with `plan` action
6. Configure team notifications (Slack, email, etc.)
