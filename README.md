# Password Support

A secure password management API built with FastAPI that allows users to generate, store, and retrieve strong passwords for different platforms.

## Features

- User registration and authentication with JWT tokens
- Secure password generation with customizable complexity
- Encrypted password storage using Fernet symmetric encryption
- DynamoDB integration for scalable data storage
- Comprehensive logging with sensitive data protection

## Prerequisites

- Python 3.10+
- AWS account with DynamoDB access
- Git

## Setup Guide

### 1. Clone the Repository

```bash
git clone https://github.com/josephdickson11/passwordsupport.git
cd passwordsupport
```

### 2. Create a Virtual Environment

```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Create a `.env` file in the project root with the following variables:

```
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=your_aws_region
USERS_TABLE_NAME=users
PASSWORDS_TABLE_NAME=passwords
FERNET_KEY=your_fernet_key
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALGORITHM=HS256
SECRET_KEY=your_secret_key
```

To generate a Fernet key:
```python
from cryptography.fernet import Fernet
print(Fernet.generate_key().decode())
```

To generate a secret key:
```python
import secrets
print(secrets.token_hex(32))
```

### 5. Create DynamoDB Tables

Create two tables in your AWS DynamoDB console:

**Users Table:**
- Table name: `users` (or as specified in .env)
- Partition key: `username` (String)

**Passwords Table:**
- Table name: `passwords` (or as specified in .env)
- Partition key: `username` (String)
- Sort key: `platform` (String)

### 6. Run the Application

```bash
python run.py
```

The API will be available at http://127.0.0.1:8000

## API Usage Guide

### Register a New User

```bash
curl -X POST "http://127.0.0.1:8000/register" \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "email": "test@example.com", "password": "securepassword"}'
```

### Login and Get Access Token

```bash
curl -X POST "http://127.0.0.1:8000/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=securepassword"
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### Generate a New Password

```bash
curl -X POST "http://127.0.0.1:8000/password" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "platform": "github",
    "nr_cap_letters": 2,
    "nr_letters": 6,
    "nr_symbols": 2,
    "nr_numbers": 2
  }'
```

Response:
```json
{
  "platform": "github",
  "password": "aB1$cDef2&"
}
```

### Retrieve a Stored Password

```bash
curl -X GET "http://127.0.0.1:8000/password/github" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Response:
```json
{
  "platform": "github",
  "password": "aB1$cDef2&"
}
```

## Security Considerations

- All passwords are encrypted before storage using Fernet symmetric encryption
- User passwords are hashed using bcrypt before storage
- JWT tokens are used for authentication with a configurable expiration time
- Sensitive information is filtered from logs
- Environment variables are used for all sensitive configuration

## Development

### Running Tests

```bash
pytest
```

### Code Formatting

```bash
black app/
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.