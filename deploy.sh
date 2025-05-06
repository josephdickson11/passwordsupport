#!/bin/bash
set -e

# Configuration
AWS_REGION="us-east-1"  # Change to your region
ECR_REPOSITORY_NAME="passwordsupport"
LAMBDA_FUNCTION_NAME="passwordsupport-api"
API_GATEWAY_NAME="passwordsupport-api"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION || \
    aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION

# Build and tag the Docker imageq
docker build -t $ECR_REPOSITORY_NAME:latest .
docker tag $ECR_REPOSITORY_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

# Push the image to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

# Create or update Lambda function
LAMBDA_EXISTS=$(aws lambda list-functions --region $AWS_REGION --query "Functions[?FunctionName=='$LAMBDA_FUNCTION_NAME'].FunctionName" --output text)

if [ -z "$LAMBDA_EXISTS" ]; then
    # Create new Lambda function
    aws lambda create-function \
        --function-name $LAMBDA_FUNCTION_NAME \
        --package-type Image \
        --code ImageUri=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest \
        --role $LAMBDA_EXECUTION_ROLE_ARN \
        --environment "Variables={AWS_REGION=$AWS_REGION}" \
        --timeout 30 \
        --memory-size 256 \
        --region $AWS_REGION
else
    # Update existing Lambda function
    aws lambda update-function-code \
        --function-name $LAMBDA_FUNCTION_NAME \
        --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest \
        --region $AWS_REGION
fi

echo "Deployment completed successfully!"