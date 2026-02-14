# Backend configuration for production environment
# Usage: terraform init -backend-config=backend-config-prod.hcl

bucket         = "your-terraform-state-bucket"
key            = "prod/health-check/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks"
encrypt        = true
