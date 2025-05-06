#!/bin/bash
set -e

# Configuration
AWS_REGION=$(aws configure get region)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_FUNCTION_NAME="passwordsupport-stack-PasswordSupportFunction-ZiSNCkIyg3z2"
USERS_TABLE=$(grep "^USERS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
PASSWORDS_TABLE=$(grep "^PASSWORDS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')

# Get the Lambda function's execution role
ROLE_ARN=$(aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --query 'Configuration.Role' --output text)
ROLE_NAME=$(echo $ROLE_ARN | cut -d '/' -f 2)

echo "Creating policy document..."
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

echo "Creating IAM policy..."
POLICY_ARN=$(aws iam create-policy \
  --policy-name PasswordSupportDynamoDBPolicy \
  --policy-document file://dynamodb-policy.json \
  --query 'Policy.Arn' \
  --output text)

echo "Attaching policy to Lambda execution role..."
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn $POLICY_ARN

echo "Lambda role updated successfully!"