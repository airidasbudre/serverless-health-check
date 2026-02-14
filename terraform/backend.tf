# S3 backend with DynamoDB state locking
# Use partial configuration for environment-specific state files
# Initialize with: terraform init -backend-config="key=${environment}/terraform.tfstate"
terraform {
  backend "s3" {
    # These values should be provided via backend config file or CLI flags
    # bucket         = "your-terraform-state-bucket"
    # key            = "staging/terraform.tfstate"  # or prod/terraform.tfstate
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-locks"
    # encrypt        = true
  }
}
