#!/bin/bash

# Source the environment variables using the same method as in deploy_existing_tables.sh
FERNET_KEY=$(grep "^FERNET_KEY=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
SECRET_KEY=$(grep "^SECRET_KEY=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
USERS_TABLE=$(grep "^USERS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
PASSWORDS_TABLE=$(grep "^PASSWORDS_TABLE_NAME=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')
TOKEN_EXPIRE=$(grep "^ACCESS_TOKEN_EXPIRE_MINUTES=" .env | cut -d '=' -f2- | tr -d '"' | tr -d "'" | tr -d ' ')

# Print the extracted values
echo "Extracted environment variables:"
echo "FERNET_KEY: ${FERNET_KEY:0:10}... (${#FERNET_KEY} characters)"
echo "SECRET_KEY: ${SECRET_KEY:0:10}... (${#SECRET_KEY} characters)"
echo "USERS_TABLE: $USERS_TABLE"
echo "PASSWORDS_TABLE: $PASSWORDS_TABLE"
echo "TOKEN_EXPIRE: $TOKEN_EXPIRE"

# Verify the Fernet key
echo -e "\nVerifying Fernet key..."
python -c "
from cryptography.fernet import Fernet
import sys

try:
    key = '$FERNET_KEY'
    cipher = Fernet(key.encode())
    test_data = b'Test message'
    encrypted = cipher.encrypt(test_data)
    decrypted = cipher.decrypt(encrypted)
    print(f'Fernet key validation: SUCCESS')
    print(f'Test encryption/decryption: {decrypted.decode()}')
except Exception as e:
    print(f'Fernet key validation: FAILED - {str(e)}')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "Fernet key validation failed. Please check your .env file."
    exit 1
fi

echo "All environment variables verified successfully!"