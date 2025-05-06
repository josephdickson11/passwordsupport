#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
LAMBDA_FUNCTION_NAME="passwordsupport-stack-PasswordSupportFunction-ZiSNCkIyg3z2"

# Get the Lambda function's execution role
ROLE_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query 'Configuration.Role' --output text)
ROLE_NAME=$(echo $ROLE_ARN | cut -d '/' -f 2)

echo "Lambda function: $LAMBDA_FUNCTION_NAME"
echo "IAM Role ARN: $ROLE_ARN"
echo "IAM Role Name: $ROLE_NAME"

# List attached policies
echo "Attached policies:"
aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[*].PolicyName' --output table