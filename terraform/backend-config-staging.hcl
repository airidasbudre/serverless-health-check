# Backend configuration for staging environment
# Usage: terraform init -backend-config=backend-config-staging.hcl

bucket         = "your-terraform-state-bucket"
key            = "staging/health-check/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
