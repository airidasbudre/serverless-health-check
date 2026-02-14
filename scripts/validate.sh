#!/bin/bash

# Validation script for serverless health check project
# Checks Terraform formatting, validation, and basic security

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "========================================="
echo "Serverless Health Check Validation"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Terraform is installed
echo "Checking Terraform installation..."
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform is not installed${NC}"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
echo -e "${GREEN}✓ Terraform $TERRAFORM_VERSION installed${NC}"
echo ""

# Check Python for Lambda validation
echo "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}WARNING: Python3 is not installed (needed for Lambda testing)${NC}"
else
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    echo -e "${GREEN}✓ Python $PYTHON_VERSION installed${NC}"
fi
echo ""

# Format check
echo "Checking Terraform formatting..."
cd "$TERRAFORM_DIR"
if terraform fmt -check -recursive; then
    echo -e "${GREEN}✓ All Terraform files are properly formatted${NC}"
else
    echo -e "${YELLOW}WARNING: Some files need formatting. Run 'terraform fmt -recursive'${NC}"
fi
echo ""

# Validation
echo "Validating Terraform configuration..."
cd "$TERRAFORM_DIR"

# Initialize without backend for validation
terraform init -backend=false > /dev/null 2>&1

if terraform validate; then
    echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
else
    echo -e "${RED}ERROR: Terraform validation failed${NC}"
    exit 1
fi
echo ""

# Security checks
echo "Running security checks..."

# Check for hardcoded secrets
echo "  Checking for hardcoded secrets..."
SECRET_PATTERNS=("password" "secret" "key" "token" "credential")
FOUND_SECRETS=0

for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -r -i "$pattern\s*=\s*\"" "$TERRAFORM_DIR" --include="*.tf" | grep -v "variable\|description\|output\|tag" > /dev/null 2>&1; then
        echo -e "${YELLOW}  WARNING: Found potential hardcoded $pattern${NC}"
        FOUND_SECRETS=1
    fi
done

if [ $FOUND_SECRETS -eq 0 ]; then
    echo -e "${GREEN}  ✓ No hardcoded secrets found${NC}"
fi

# Check for wildcard in IAM policies
echo "  Checking for wildcard (*) in IAM resource ARNs..."
if grep -r "Resource.*\"\*\"" "$TERRAFORM_DIR/modules/iam" | grep -v "VPC\|KMS\|CloudWatch" > /dev/null 2>&1; then
    echo -e "${RED}  ERROR: Found wildcard (*) in IAM resource ARNs${NC}"
    grep -r "Resource.*\"\*\"" "$TERRAFORM_DIR/modules/iam" | grep -v "VPC\|KMS\|CloudWatch"
    exit 1
else
    echo -e "${GREEN}  ✓ No inappropriate wildcards in IAM policies${NC}"
fi

# Check for encryption settings
echo "  Checking encryption settings..."
if grep -r "server_side_encryption" "$TERRAFORM_DIR/modules/dynamodb" > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ DynamoDB encryption enabled${NC}"
else
    echo -e "${RED}  ERROR: DynamoDB encryption not configured${NC}"
    exit 1
fi

# Check for KMS key rotation
if grep -r "enable_key_rotation.*true" "$TERRAFORM_DIR/modules/kms" > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ KMS key rotation enabled${NC}"
else
    echo -e "${YELLOW}  WARNING: KMS key rotation not enabled${NC}"
fi

# Check for point-in-time recovery
if grep -r "point_in_time_recovery" "$TERRAFORM_DIR/modules/dynamodb" > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ DynamoDB point-in-time recovery enabled${NC}"
else
    echo -e "${YELLOW}  WARNING: DynamoDB point-in-time recovery not enabled${NC}"
fi

echo ""

# Lambda validation
echo "Validating Lambda function..."
LAMBDA_DIR="$PROJECT_ROOT/lambda"

if [ -f "$LAMBDA_DIR/health_check.py" ]; then
    # Check Python syntax
    if python3 -m py_compile "$LAMBDA_DIR/health_check.py" 2>/dev/null; then
        echo -e "${GREEN}✓ Lambda Python syntax is valid${NC}"
    else
        echo -e "${RED}ERROR: Lambda Python syntax error${NC}"
        exit 1
    fi

    # Check for required environment variables
    if grep -q "TABLE_NAME" "$LAMBDA_DIR/health_check.py" && \
       grep -q "ENVIRONMENT" "$LAMBDA_DIR/health_check.py"; then
        echo -e "${GREEN}✓ Lambda uses environment variables${NC}"
    else
        echo -e "${RED}ERROR: Lambda missing required environment variables${NC}"
        exit 1
    fi

    # Check for input validation
    if grep -q "payload.*not in" "$LAMBDA_DIR/health_check.py"; then
        echo -e "${GREEN}✓ Lambda has input validation${NC}"
    else
        echo -e "${YELLOW}WARNING: Lambda may be missing input validation${NC}"
    fi
else
    echo -e "${RED}ERROR: Lambda function not found${NC}"
    exit 1
fi

echo ""

# Module structure validation
echo "Validating module structure..."

REQUIRED_MODULES=("api-gateway" "dynamodb" "iam" "kms" "lambda" "monitoring")

for module in "${REQUIRED_MODULES[@]}"; do
    MODULE_DIR="$TERRAFORM_DIR/modules/$module"

    if [ ! -d "$MODULE_DIR" ]; then
        echo -e "${RED}ERROR: Module $module not found${NC}"
        exit 1
    fi

    # Check for required files
    for file in "main.tf" "variables.tf" "outputs.tf"; do
        if [ ! -f "$MODULE_DIR/$file" ]; then
            echo -e "${RED}ERROR: $file missing in $module module${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}✓ Module $module structure valid${NC}"
done

echo ""

# Check for required outputs
echo "Validating outputs..."
REQUIRED_OUTPUTS=("health_check_url" "lambda_function_name" "dynamodb_table_name")

for output in "${REQUIRED_OUTPUTS[@]}"; do
    if grep -q "output \"$output\"" "$TERRAFORM_DIR/outputs.tf"; then
        echo -e "${GREEN}✓ Output $output defined${NC}"
    else
        echo -e "${RED}ERROR: Output $output not defined${NC}"
        exit 1
    fi
done

echo ""

# Final summary
echo "========================================="
echo -e "${GREEN}Validation Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Update backend configuration in terraform/backend-config-*.hcl"
echo "  2. Update alarm_email in terraform/*.tfvars"
echo "  3. Run: cd terraform && terraform init"
echo "  4. Run: terraform plan -var-file=staging.tfvars"
echo "  5. Run: terraform apply -var-file=staging.tfvars"
echo ""
