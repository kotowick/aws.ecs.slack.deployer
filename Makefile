STAGE ?= "staging"
AWS_REGION ?= "us-east-1"
AWS_PROFILE ?= "default"

.DEFAULT_GOAL := help

all:
	: '$(STAGE)'
	: '$(AWS_REGION)'
	: '$(AWS_PROFILE)'

package: ## Packages the code for AWS Lambda
	@echo 'Package the app for deploy'
	@echo '--------------------------'
	@sls package --region $(AWS_REGION) --aws-profile $(AWS_PROFILE) --stage $(STAGE)

setup-dependencies: create-certificate create-custom-domain ## Setup dependencies

deploy: deploy-sls create-custom-resources ## Deploy Serverless stack and create custom resources defined in ./scripts/custom_resources.rb

remove: remove-custom-resources remove-sls ## Remove custom resources defined in ./scripts/custom_resources.rb and remove Serverless stack

deploy-sls: ## Setup the Serverless stack only (do not run the custom resource creator)
	@echo 'Deploy the app'
	@echo '--------------------------'
	@sls deploy --force --region $(AWS_REGION) --aws-profile $(AWS_PROFILE) --stage $(STAGE)

remove-sls: ## Remove the Serverless stack only (and keep custom resources)
	@echo "Removing the app"
	@echo '--------------------------'
	@sls remove --region $(AWS_REGION) --aws-profile $(AWS_PROFILE) --stage $(STAGE)

create-custom-resources: ## Create custom resources defined in ./scripts/custom_resources.rb
	@echo "Creating SNS topics"
	@echo '--------------------------'
	ACTION=CREATE ruby ./scripts/custom_resources.rb

remove-custom-resources: ## Remove custom resources defined in ./scripts/custom_resources.rb
	@echo "Removing SNS topics"
	@echo '--------------------------'
	ACTION=REMOVE ruby ./scripts/custom_resources.rb

create-certificate: ## Create a certificate in ACM
	@echo "Creating Certificate"
	@echo '--------------------------'
	@sls create-cert --region $(AWS_REGION) --aws-profile $(AWS_PROFILE) --stage $(STAGE)

create-custom-domain: ## Create a custom domain in R53 and API Gateway
	@echo "Creating Domain"
	@echo '--------------------------'
	@sls create_domain --region $(AWS_REGION) --aws-profile $(AWS_PROFILE) --stage $(STAGE)

seed: ## Seed the applications dynamo table (custom functionality)
	@echo "Seeding Dynamo Table"
	@echo '--------------------------'
	ruby ./scripts/seed.rb

.PHONY: help

help: ## Show helpful information
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
