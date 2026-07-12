#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_NAME="passwordsupport"
STACK_NAME="passwordsupport-stack"

# Build and push Docker image
echo "Building and pushing Docker image..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION || \
    aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION

# Build and tag the Docker image
docker build -t $ECR_REPOSITORY_NAME:latest .
docker tag $ECR_REPOSITORY_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

# Push the image to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

# Get your Fernet key and Secret key from .env file
FERNET_KEY=$(grep "^FERNET_KEY=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
USERS_TABLE=$(grep "^USERS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
PASSWORDS_TABLE=$(grep "^PASSWORDS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
TOKEN_EXPIRE=$(grep "^ACCESS_TOKEN_EXPIRE_MINUTES=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')

# Deploy with SAM
echo "Deploying CloudFormation stack..."
sam deploy \
  --template-file template.yaml \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --image-repository $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME \
  --parameter-overrides \
    UsersTableName=${USERS_TABLE:-users} \
    PasswordsTableName=${PASSWORDS_TABLE:-passwords} \
    FernetKey=$FERNET_KEY \
    SecretKey=$SECRET_KEY \
    TokenExpireMinutes=${TOKEN_EXPIRE:-30}

# Get the API Gateway URL
API_URL=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)

echo "Deployment completed successfully!"
echo "API Gateway URL: $API_URL"