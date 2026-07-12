#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_FUNCTION_NAME="passwordsupport-stack-PasswordSupportFunction-ZiSNCkIyg3z2"
USERS_TABLE=$(grep "^USERS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
PASSWORDS_TABLE=$(grep "^PASSWORDS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
ROLE_NAME="passwordsupport-lambda-role-2"

# Create trust policy document for Lambda
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create IAM role
echo "Creating IAM role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json

# Attach AWSLambdaBasicExecutionRole for CloudWatch Logs
echo "Attaching AWSLambdaBasicExecutionRole..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create DynamoDB policy document
cat > dynamodb-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query",
                "dynamodb:Scan"
            ],
            "Resource": [
                "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${USERS_TABLE:-users}",
                "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${PASSWORDS_TABLE:-passwords}"
            ]
        }
    ]
}
EOF

# Create and attach DynamoDB policy
echo "Creating and attaching DynamoDB policy..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name PasswordSupportDynamoDBPolicy \
  --policy-document file://dynamodb-policy.json

# Wait for role to propagate
echo "Waiting for role to propagate..."
sleep 10

# Update Lambda function to use the new role
echo "Updating Lambda function to use the new role..."
aws lambda update-function-configuration \
  --function-name $LAMBDA_FUNCTION_NAME \
  --role "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
  --region $AWS_REGION

echo "Lambda role created and attached successfully!"