.PHONY: help init-staging init-prod plan-staging plan-prod apply-staging apply-prod destroy-staging destroy-prod validate format clean test

# Default target
help:
	@echo "Serverless Health Check - Makefile Commands"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make init-staging      - Initialize Terraform for staging"
	@echo "  make init-prod         - Initialize Terraform for production"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make plan-staging      - Plan staging deployment"
	@echo "  make plan-prod         - Plan production deployment"
	@echo "  make apply-staging     - Apply staging deployment"
	@echo "  make apply-prod        - Apply production deployment"
	@echo ""
	@echo "Validation Commands:"
	@echo "  make validate          - Validate Terraform configuration"
	@echo "  make format            - Format Terraform files"
	@echo "  make test              - Run validation script"
	@echo ""
	@echo "Cleanup Commands:"
	@echo "  make destroy-staging   - Destroy staging resources"
	@echo "  make destroy-prod      - Destroy production resources"
	@echo "  make clean             - Clean Terraform cache"

# Initialization
init-staging:
	cd terraform && terraform init -backend-config=backend-config-staging.hcl

init-prod:
	cd terraform && terraform init -backend-config=backend-config-prod.hcl

# Planning
plan-staging:
	cd terraform && terraform plan -var-file=staging.tfvars -out=staging.tfplan

plan-prod:
	cd terraform && terraform plan -var-file=prod.tfvars -out=prod.tfplan

# Deployment
apply-staging:
	cd terraform && terraform apply staging.tfplan

apply-prod:
	@echo "WARNING: This will deploy to PRODUCTION"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform apply prod.tfplan; \
	fi

# Destruction
destroy-staging:
	cd terraform && terraform destroy -var-file=staging.tfvars

destroy-prod:
	@echo "WARNING: This will destroy PRODUCTION resources"
	@read -p "Are you absolutely sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform && terraform destroy -var-file=prod.tfvars; \
	fi

# Validation
validate:
	cd terraform && terraform init -backend=false && terraform validate

format:
	cd terraform && terraform fmt -recursive

test:
	./scripts/validate.sh

# Cleanup
clean:
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/*.tfplan
	rm -f terraform/modules/lambda/*.zip

# Quick deployment workflow
deploy-staging: init-staging plan-staging apply-staging

deploy-prod: init-prod plan-prod apply-prod

# View outputs
outputs-staging:
	cd terraform && terraform output

outputs-prod:
	cd terraform && terraform output

# Test endpoint
test-staging:
	@URL=$$(cd terraform && terraform output -raw health_check_url 2>/dev/null); \
	if [ -n "$$URL" ]; then \
		echo "Testing staging endpoint: $$URL"; \
		curl -X POST "$$URL" \
			-H "Content-Type: application/json" \
			-d '{"payload": "test from makefile"}' | jq; \
	else \
		echo "ERROR: Cannot get health_check_url. Run 'make deploy-staging' first"; \
	fi

test-prod:
	@URL=$$(cd terraform && terraform output -raw health_check_url 2>/dev/null); \
	if [ -n "$$URL" ]; then \
		echo "Testing production endpoint: $$URL"; \
		curl -X POST "$$URL" \
			-H "Content-Type: application/json" \
			-d '{"payload": "test from makefile"}' | jq; \
	else \
		echo "ERROR: Cannot get health_check_url. Run 'make deploy-prod' first"; \
	fi
