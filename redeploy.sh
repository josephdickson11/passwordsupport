#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY_NAME="passwordsupport"
LAMBDA_FUNCTION_NAME="passwordsupport-api"

echo "Building Docker image..."
docker build -t $ECR_REPOSITORY_NAME:latest .

# Test imports inside the container
#echo "Testing imports inside the container..."
#docker run --rm $ECR_REPOSITORY_NAME:latest python -c "import mangum; print('Mangum version:', mangum.__version__)"

echo "Tagging and pushing Docker image..."
docker tag $ECR_REPOSITORY_NAME:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest

echo "Updating Lambda function..."
aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_NAME:latest \
    --region $AWS_REGION

echo "Waiting for Lambda update to complete..."
aws lambda wait function-updated \
    --function-name $LAMBDA_FUNCTION_NAME \
    --region $AWS_REGION

echo "Redeployment completed successfully!"

# Get the API Gateway URL
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='password-support-api'].id" --output text)
API_URL="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
echo "API Gateway URL: $API_URL"